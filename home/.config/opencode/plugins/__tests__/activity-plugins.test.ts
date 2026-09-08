import {
	afterAll,
	afterEach,
	beforeEach,
	describe,
	expect,
	spyOn,
	test,
} from "bun:test"
import { watch } from "node:fs"
import {
	chmod,
	mkdtemp,
	readFile,
	realpath,
	rm,
	writeFile,
} from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"
import type { CommandDefinition } from "@opencode-ai/plugin/promise/command"
import type { SessionPrompt } from "@opencode-ai/plugin/promise/session"
import KeepGoing from "../keep-going"
import Worktrunk from "../worktrunk"

type Item =
	ReturnType<Plugin.Context["event"]["subscribe"]> extends AsyncIterable<
		infer T
	>
		? T
		: never
type Messages = Awaited<ReturnType<Plugin.Context["session"]["context"]>>

function deferred<T>() {
	let resolve!: (value: T) => void
	const promise = new Promise<T>((done) => {
		resolve = done
	})
	return { promise, resolve }
}

// emit resolves when the consumer asks for the next event, not just on delivery.
function events() {
	let pending = deferred<IteratorResult<Item>>()
	let ready = deferred<void>()
	let consumed: (() => void) | undefined
	let closed = false
	let signal: AbortSignal | undefined
	const close = () => {
		closed = true
		signal?.removeEventListener("abort", close)
		pending.resolve({ done: true, value: undefined })
		consumed?.()
		return Promise.resolve({ done: true as const, value: undefined })
	}
	return {
		get closed() {
			return closed
		},
		subscribe(options?: { signal?: AbortSignal }) {
			signal = options?.signal
			signal?.addEventListener("abort", close, { once: true })
			if (signal?.aborted) void close()
			return {
				[Symbol.asyncIterator]() {
					return {
						next() {
							consumed?.()
							consumed = undefined
							if (closed)
								return Promise.resolve({
									done: true as const,
									value: undefined,
								})
							ready.resolve()
							return pending.promise
						},
						return: close,
					}
				},
			}
		},
		async emit(item: unknown) {
			await ready.promise
			if (closed) return
			const done = deferred<void>()
			consumed = () => done.resolve()
			const current = pending
			pending = deferred<IteratorResult<Item>>()
			ready = deferred<void>()
			current.resolve({ done: false, value: item as Item })
			await done.promise
		},
	}
}

function harness() {
	const stream = events()
	const commands = new Map<string, CommandDefinition>()
	let promptHook: ((input: SessionPrompt) => Promise<void> | void) | undefined
	let toolHook: ((input: { tool: string }) => Promise<void> | void) | undefined
	const context = {
		location: { directory: "/test", workspaceID: "ws_test" },
		event: { subscribe: stream.subscribe },
		command: {
			async transform(
				callback: (editor: {
					add(definition: CommandDefinition): void
				}) => void,
			) {
				callback({
					add: (definition) => {
						commands.set(definition.name, definition)
					},
				})
				return {
					dispose: async () => {
						commands.clear()
					},
				}
			},
		},
		tool: {
			async hook(name: string, callback: typeof toolHook) {
				expect(name).toBe("execute.before")
				toolHook = callback
				return {
					dispose: async () => {
						toolHook = undefined
					},
				}
			},
		},
		session: {
			async hook(name: string, callback: typeof promptHook) {
				expect(name).toBe("prompt")
				promptHook = callback
				return {
					dispose: async () => {
						promptHook = undefined
					},
				}
			},
			get: async (_input: { sessionID: string }) => ({
				parentID: undefined as string | undefined,
			}),
			context: async (_input: { sessionID: string }): Promise<Messages> => [],
			prompt: async (input: {
				sessionID: string
				text: string
				delivery?: string
			}) => {
				await promptHook?.({
					sessionID: input.sessionID,
					prompt: { text: input.text },
				} as SessionPrompt)
			},
		},
	}
	return {
		context,
		stream,
		commands,
		setup: (plugin: Plugin.Plugin) =>
			plugin.setup(context as unknown as Plugin.Context),
		question: (tool = "question") => toolHook?.({ tool }),
		user: (text: string) =>
			promptHook?.({
				sessionID: "ses_test",
				prompt: { text },
			} as SessionPrompt),
		async start() {
			const command = commands.get("keep-going")
			if (!command) throw new Error("Missing keep-going command")
			await command.execute({
				sessionID: "ses_test",
				prompt: { text: "ignored arguments" },
				delivery: "queue",
			} as Parameters<CommandDefinition["execute"]>[0])
		},
	}
}

const status = (type = "idle", location?: unknown) => ({
	type: "session.status",
	data: { sessionID: "ses_test", status: { type } },
	location,
})
const deleted = { type: "session.deleted", data: { sessionID: "ses_test" } }
const assistant = (text: string, extra = {}) => ({
	type: "assistant",
	id: "msg_reply",
	content: [{ type: "text", text }],
	...extra,
})
const transcript = (...messages: unknown[]) => messages as Messages

let directory: string
let previous: NodeJS.ProcessEnv
const cleanups: Plugin.Cleanup[] = []
const errors = spyOn(console, "error").mockImplementation(() => {})

afterAll(() => errors.mockRestore())

beforeEach(async () => {
	previous = { ...process.env }
	directory = await realpath(
		await mkdtemp(join(tmpdir(), "opencode-activity-")),
	)
	for (const name of ["wt"]) {
		const executable = join(directory, name)
		await writeFile(
			executable,
			'#!/bin/sh\nprintf "%s\\n" "$PWD|$*" >> "$PLUGIN_TEST_LOG"\n',
		)
		await chmod(executable, 0o755)
	}
	process.env.PATH = `${directory}:${process.env.PATH}`
	process.env.PLUGIN_TEST_LOG = join(directory, "calls")
	errors.mockClear()
})

afterEach(async () => {
	for (const cleanup of cleanups.splice(0)) await cleanup()
	process.env = previous
	await rm(directory, { recursive: true, force: true })
})

async function setup(plugin: Plugin.Plugin, host = harness()) {
	const cleanup = await host.setup(plugin)
	if (cleanup) cleanups.push(cleanup)
	return { ...host, cleanup: cleanup ?? (() => {}) }
}

async function calls() {
	return (await readFile(join(directory, "calls"), "utf8").catch(() => ""))
		.trim()
		.split("\n")
		.filter(Boolean)
}

describe("keep-going Promise plugin", () => {
	test("registers the command, preserves delivery, replays once per reply, and stops only on exact done", async () => {
		const host = await setup(KeepGoing)
		const prompt = spyOn(host.context.session, "prompt")
		await host.start()
		const text = prompt.mock.calls[0]![0].text
		expect(prompt.mock.calls[0]![0].delivery).toBe("queue")
		expect(text).toContain("I AM DONE")
		host.context.session.context = async () =>
			transcript({ type: "user", text }, assistant("more work"))
		await host.stream.emit(status("busy"))
		await host.stream.emit(status("idle", { directory: "/other" }))
		expect(prompt).toHaveBeenCalledTimes(1)
		await host.stream.emit(status())
		await host.stream.emit(status())
		expect(prompt).toHaveBeenCalledTimes(2)
		host.context.session.context = async () =>
			transcript({ type: "user", text }, assistant("more work"), {
				type: "user",
				id: "msg_replay",
				text,
			})
		await host.stream.emit(status())
		expect(prompt).toHaveBeenCalledTimes(2)
		host.context.session.context = async () =>
			transcript(
				{ type: "user", text },
				assistant(" I AM DONE\n", {
					id: "msg_done",
					content: [
						{ type: "reasoning", text: "checked" },
						{ type: "text", text: " I AM DONE\n" },
					],
				}),
			)
		await host.stream.emit(status())
		await host.stream.emit(status())
		expect(prompt).toHaveBeenCalledTimes(2)
	})

	test.each(["tool", "error", "extra-text", "unrelated-user", "later-user"])(
		"does not stop on %s done-like replies",
		async (kind) => {
			const host = await setup(KeepGoing)
			const prompt = spyOn(host.context.session, "prompt")
			await host.start()
			const text = prompt.mock.calls[0]![0].text
			const reply = assistant(
				kind === "extra-text" ? "I AM DONE and more" : "I AM DONE",
			)
			const messages: unknown[] = [
				{ type: "user", text: kind === "unrelated-user" ? "other" : text },
				reply,
			]
			if (kind === "tool")
				Object.assign(reply, {
					content: [...reply.content, { type: "tool", name: "bash" }],
				})
			if (kind === "error")
				Object.assign(reply, { error: { message: "failed" } })
			if (kind === "later-user") messages.push({ type: "user", text })
			host.context.session.context = async () => transcript(...messages)
			await host.stream.emit(status())
			expect(prompt).toHaveBeenCalledTimes(2)
		},
	)

	test.each(["user", "unload"])(
		"cancels in-flight replay on %s",
		async (reason) => {
			const host = await setup(KeepGoing)
			const prompt = spyOn(host.context.session, "prompt")
			await host.start()
			const lookup = deferred<Messages>()
			const entered = deferred<void>()
			host.context.session.context = () => {
				entered.resolve()
				return lookup.promise
			}
			const emitted = host.stream.emit(status())
			await entered.promise
			const stopping =
				reason === "user" ? host.user("do something else") : host.cleanup()
			lookup.resolve(transcript(assistant("more")))
			await stopping
			await emitted
			expect(prompt).toHaveBeenCalledTimes(1)
			if (reason === "unload") {
				expect(host.commands.size).toBe(0)
				expect(host.stream.closed).toBe(true)
			}
		},
	)

	test("deletion clears state and a replay failure does not kill the listener", async () => {
		const host = await setup(KeepGoing)
		const prompt = spyOn(host.context.session, "prompt")
		await host.start()
		host.context.session.context = async () => transcript(assistant("more"))
		prompt.mockRejectedValueOnce(new Error("temporary failure"))
		await host.stream.emit(status())
		await host.stream.emit(status())
		expect(prompt).toHaveBeenCalledTimes(3)
		expect(errors).toHaveBeenCalledTimes(1)
		await host.stream.emit(deleted)
		await host.stream.emit(status())
		expect(prompt).toHaveBeenCalledTimes(3)
	})

	test("failed command setup disposes the earlier registration", async () => {
		const host = harness()
		host.context.session.hook = async () => {
			throw new Error("registration failed")
		}
		await expect(host.setup(KeepGoing)).rejects.toThrow("registration failed")
		expect(host.commands.size).toBe(0)
	})

	test("a failed initial prompt disarms the loop and a fresh instance starts inactive", async () => {
		const host = await setup(KeepGoing)
		const prompt = spyOn(host.context.session, "prompt").mockRejectedValueOnce(
			new Error("prompt failed"),
		)
		await expect(host.start()).rejects.toThrow("prompt failed")
		await host.stream.emit(status())
		expect(prompt).toHaveBeenCalledTimes(1)
		await host.start()
		await host.cleanup()
		const next = await setup(KeepGoing)
		const nextPrompt = spyOn(next.context.session, "prompt")
		await next.stream.emit(status())
		expect(nextPrompt).not.toHaveBeenCalled()
	})
})

describe("worktrunk Promise plugin", () => {
	test("sets busy/retry/idle markers in the plugin location, clears on delete, and closes the stream", async () => {
		const host = harness()
		host.context.location.directory = directory
		const running = await setup(Worktrunk, host)
		await host.stream.emit(status("busy"))
		await host.stream.emit(status("retry"))
		await host.stream.emit(status())
		await host.stream.emit(status("busy", { directory: "/other" }))
		await host.stream.emit(deleted)
		expect(await calls()).toEqual([
			`${directory}|config state marker set \u{1f916}`,
			`${directory}|config state marker set \u{1f916}`,
			`${directory}|config state marker set \u{1f4ac}`,
			`${directory}|config state marker clear`,
		])
		await running.cleanup()
		expect(host.stream.closed).toBe(true)
		await host.stream.emit(status())
		expect(await calls()).toHaveLength(4)
	})

	test("missing wt is harmless and does not terminate the stream", async () => {
		await rm(join(directory, "wt"))
		process.env.PATH = directory
		const host = harness()
		host.context.location.directory = directory
		await setup(Worktrunk, host)
		await host.stream.emit(status("busy"))
		await host.stream.emit(deleted)
		expect(errors).not.toHaveBeenCalled()
	})
})

test.each([Worktrunk])(
	"%s unload aborts an in-flight subprocess without leaving the listener running",
	async (plugin) => {
		const executable = join(directory, "wt")
		await writeFile(
			executable,
			'#!/bin/sh\nprintf started >> "$PLUGIN_TEST_LOG"\nexec /bin/sleep 60\n',
		)
		const started = deferred<void>()
		const watcher = watch(directory, (_event, name) => {
			if (name === "calls") started.resolve()
		})
		try {
			const host = harness()
			host.context.location.directory = directory
			const running = await setup(plugin, host)
			const pending = host.stream.emit(status("busy"))
			await started.promise
			await running.cleanup()
			await pending
			expect(host.stream.closed).toBe(true)
			expect(errors).not.toHaveBeenCalled()
		} finally {
			watcher.close()
		}
	},
)
