import { expect, test } from "bun:test"
import net from "node:net"
import { mkdtemp, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { setup } from "./tui"
import type { OpenCodeEvent } from "@opencode-ai/client"

test("pane selection, descendants, serialized state, retries and cleanup", async () => {
	const directory = await mkdtemp(join(tmpdir(), "herdr-beta-"))
	const socket = join(directory, "s")
	const previous = { ...process.env }
	const reports: {
		method: string
		params: {
			agent_session_id: string
			state?: string
			session_start_source?: string
		}
	}[] = []
	const server = net.createServer((client) => {
		client.once("data", (data) => {
			reports.push(JSON.parse(data.toString()))
			client.end("{}\n")
		})
	})
	await new Promise<void>((resolve) => server.listen(socket, resolve))
	Object.assign(process.env, {
		HERDR_ENV: "1",
		HERDR_PANE_ID: "test-pane",
		HERDR_SOCKET_PATH: socket,
	})
	let route: { type: "home" } | { type: "session"; sessionID: string } = {
		type: "session",
		sessionID: "a",
	}
	const sessions = [
		{ id: "a" },
		{ id: "child", parentID: "a" },
		{ id: "grandchild", parentID: "child" },
		{ id: "b" },
		{ id: "other", parentID: "b" },
	]
	const listeners = new Set<(event: { details: OpenCodeEvent }) => void>()
	const created = new Set<(event: OpenCodeEvent) => void>()
	const context = {
		ui: { router: { current: () => route } },
		data: {
			on: (_type: string, handler: (event: OpenCodeEvent) => void) => {
				created.add(handler)
				return () => {
					created.delete(handler)
				}
			},
			listen: (handler: (event: { details: OpenCodeEvent }) => void) => {
				listeners.add(handler)
				return () => {
					listeners.delete(handler)
				}
			},
			session: {
				list: () => sessions,
				get: (id: string) => sessions.find((session) => session.id === id),
				family: () => sessions.map((session) => session.id),
				status: () => "idle",
				permission: { list: () => [] },
				form: { list: () => [] },
			},
		},
	} as unknown as Parameters<typeof setup>[0]
	const emit = (type: string, data: object) => {
		const event = { type, data } as OpenCodeEvent
		if (type === "session.created")
			for (const handler of created) handler(event)
		for (const handler of listeners) handler({ details: event })
	}
	let cleanup: Awaited<ReturnType<typeof setup>>
	try {
		cleanup = await setup(context)
		await Bun.sleep(250)
		expect(
			reports.filter((r) => r.params.session_start_source === "select").length,
		).toBeGreaterThanOrEqual(2)
		expect(reports.every((r) => r.params.agent_session_id === "a")).toBe(true)
		reports.length = 0
		emit("session.status", { sessionID: "b", status: { type: "busy" } })
		emit("permission.asked", { sessionID: "other" })
		emit("form.created", { form: { sessionID: "global" } })
		emit("session.status", { sessionID: "child", status: { type: "idle" } })
		emit("permission.asked", { sessionID: "grandchild" })
		emit("permission.replied", { sessionID: "grandchild" })
		await Bun.sleep(50)
		expect(
			reports.map((r) => [r.params.agent_session_id, r.params.state]),
		).toEqual([
			["a", "blocked"],
			["a", "working"],
		])
		route = { type: "session", sessionID: "grandchild" }
		emit("form.created", { form: { sessionID: "child" } })
		await Bun.sleep(30)
		expect(reports.at(-1)?.params).toMatchObject({
			agent_session_id: "a",
			state: "blocked",
		})
		emit("session.created", { sessionID: "new-child", parentID: "grandchild" })
		emit("form.cancelled", { sessionID: "new-child" })
		await Bun.sleep(30)
		expect(reports.at(-1)?.params).toMatchObject({
			agent_session_id: "a",
			state: "working",
		})
		emit("session.execution.failed", { sessionID: "a" })
		await Bun.sleep(30)
		expect(reports.at(-1)?.params.state).toBe("blocked")
		reports.length = 0
		// A queued event for the previous selection must be discarded.
		emit("permission.asked", { sessionID: "a" })
		route = { type: "session", sessionID: "b" }
		emit("permission.asked", { sessionID: "a" })
		await Bun.sleep(150)
		expect(reports.length).toBeGreaterThan(0)
		expect(reports.every((r) => r.params.agent_session_id === "b")).toBe(true)
		route = { type: "home" }
		await Bun.sleep(120)
		reports.length = 0
		emit("permission.asked", { sessionID: "b" })
		await Bun.sleep(30)
		expect(reports).toEqual([])
		await cleanup?.()
		expect(listeners.size).toBe(0)
		expect(created.size).toBe(0)
		route = { type: "session", sessionID: "a" }
		await Bun.sleep(200)
		expect(reports).toEqual([])
	} finally {
		await cleanup?.()
		for (const key of ["HERDR_ENV", "HERDR_PANE_ID", "HERDR_SOCKET_PATH"]) {
			if (previous[key] === undefined) delete process.env[key]
			else process.env[key] = previous[key]
		}
		await new Promise<void>((resolve) => server.close(() => resolve()))
		await rm(directory, { recursive: true })
	}
})
