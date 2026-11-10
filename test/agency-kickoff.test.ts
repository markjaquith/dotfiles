import { describe, expect, test } from "bun:test"
import { accessSync, constants } from "node:fs"
import { main, type Runtime } from "../bin/agency-kickoff.ts"

type JsonObject = Record<string, unknown>
const root = "/work base/owner's project"
const env = { HERDR_ENV: "1", HERDR_WORKSPACE_ID: "w2" }
const rexEnv = { REX_SESSION: "session:s1", SHELL: "/bin/zsh" }

function context(
	kind: "task" | "phase" | "epic",
	mode = kind === "epic" ? "orchestration" : "execution",
	readiness: JsonObject = { ready: true, terminal: false, blockers: [] },
) {
	const path =
		kind === "phase"
			? `${root}/tasks/task-1/phases/phase-2/PHASE.md`
			: kind === "epic"
				? `${root}/epics/epic-1/EPIC.md`
				: `${root}/tasks/task-1/TASK.md`
	return {
		target: {
			kind,
			archived: false,
			path,
			...(kind === "epic" ? { epicId: "epic-1" } : { taskId: "task-1" }),
			...(kind === "phase" ? { phaseId: "phase-2" } : {}),
		},
		authority: { mode },
		graph: { readiness, aggregate: { status: "open" } },
		validation: { valid: true, warnings: [] },
	}
}

const ok = (result: unknown) => ({
	status: 0,
	stdout: JSON.stringify({ version: 1, ok: true, result }),
	stderr: "",
})
const fail = (code: string, message = "diagnostic") => ({
	status: 1,
	stdout: JSON.stringify({ version: 1, ok: false, error: { code, message } }),
	stderr: "",
})
const herdr = (type: string, result: JsonObject) => ({
	status: 0,
	stdout: JSON.stringify({ id: "cli:x", result: { type, ...result } }),
	stderr: "",
})
const quiet = { status: 0, stdout: "", stderr: "" }
const preview = { validation: { valid: true, issues: [] }, workspace: {} }
const tasks = [
	{ id: "task-1", path: `${root}/tasks/task-1/TASK.md`, data: {} },
	{
		id: "abc-42-add-thing",
		path: `${root}/tasks/abc-42-add-thing/TASK.md`,
		data: { ticketUrl: null },
	},
	{
		id: "renamed",
		path: `${root}/tasks/renamed/TASK.md`,
		data: { ticketUrl: "https://example.atlassian.net/browse/ABC-7" },
	},
]

function fake(
	responses: {
		context?: JsonObject
		prepare?: ReturnType<typeof ok>
		existing?: string[]
		rex?: { status: number; stdout: string; stderr: string }
	} = {},
) {
	const calls: string[][] = []
	const events: JsonObject[] = []
	const io: Runtime = {
		async run(argv) {
			calls.push(argv)
			const [command, ...rest] = argv
			if (command === "rex")
				return (
					responses.rex ?? {
						status: 0,
						stdout: JSON.stringify({
							window_id: "window:w9",
							block_ids: ["block:b1", "block:b2"],
							revision: 3,
						}),
						stderr: "",
					}
				)
			if (command === "herdr") {
				if (rest[0] === "tab")
					return herdr("tab_created", {
						tab: { tab_id: "w2:t9" },
						root_pane: { pane_id: "w2:p1" },
					})
				if (rest[1] === "split")
					return herdr("pane_info", { pane: { pane_id: "w2:p2" } })
				return quiet
			}
			const sub = rest[0] === "--workbase" ? rest.slice(2) : rest
			if (sub[0] === "task") return ok(tasks)
			if (sub[0] === "context")
				return /^(ABC-|https)/i.test(sub[1]!)
					? fail("CONTEXT_ERROR", "Target document does not exist")
					: ok(responses.context ?? context("task"))
			if (sub[0] === "work") return responses.prepare ?? ok(preview)
			throw new Error(`Unexpected call: ${argv.join(" ")}`)
		},
		emit: (event) => events.push(event),
		exists: (path) => (responses.existing ?? []).includes(path),
		checkExecutable: (path) => {
			if (!path.endsWith("cli")) throw new Error("not executable")
		},
	}
	return { io, calls, events }
}

describe("agency-kickoff", () => {
	test("entrypoint is executable", () => {
		accessSync(
			new URL("../bin/agency-kickoff", import.meta.url).pathname,
			constants.X_OK,
		)
	})

	test("launches a task: preflight, tab, editor split, worker and editor commands", async () => {
		const { io, calls, events } = fake()
		const status = await main(
			["task-1"],
			io,
			{ ...env, OPENCODE_CONFIG_CONTENT: '{"a":1}' },
			root,
		)
		expect(status).toBe(0)
		const dir = `${root}/tasks/task-1`
		expect(calls).toEqual([
			["agency", "context", "task-1", "--json"],
			["agency", "work", "prepare", dir, "--dry-run", "--json"],
			[
				"herdr",
				"tab",
				"create",
				"--workspace",
				"w2",
				"--cwd",
				dir,
				"--label",
				"task-1",
				"--no-focus",
				"--env",
				'OPENCODE_CONFIG_CONTENT={"a":1}',
			],
			[
				"herdr",
				"pane",
				"split",
				"--pane",
				"w2:p1",
				"--direction",
				"right",
				"--cwd",
				dir,
				"--no-focus",
				"--env",
				'OPENCODE_CONFIG_CONTENT={"a":1}',
			],
			[
				"herdr",
				"pane",
				"run",
				"w2:p1",
				"agency work . --auto || herdr notification show 'Agency launch failed' --body 'task-1: agency work exited with an error. See its tab.' --sound request",
			],
			["herdr", "pane", "run", "w2:p2", "nvim -- TASK.md"],
		])
		expect(events).toEqual([
			{
				event: "launched",
				intent: "launch",
				mux: "herdr",
				workspaceId: "w2",
				target: "task-1",
				kind: "task",
				documentPath: `${dir}/TASK.md`,
				tabId: "w2:t9",
				workerPaneId: "w2:p1",
				editorPaneId: "w2:p2",
			},
		])
	})

	test("--open omits --auto; task/phase selects a phase", async () => {
		const { io, calls, events } = fake({ context: context("phase") })
		expect(await main(["task-1/phase-2", "--open"], io, env, root)).toBe(0)
		expect(calls[0]).toEqual([
			"agency",
			"context",
			"--task",
			"task-1",
			"--phase",
			"phase-2",
			"--json",
		])
		expect(calls.find((call) => call.includes("--label"))).toContain(
			"task-1/phase-2",
		)
		expect(calls.at(-2)![4]).toStartWith("agency work . || ")
		expect(calls.at(-1)).toEqual([
			"herdr",
			"pane",
			"run",
			"w2:p2",
			"nvim -- PHASE.md",
		])
		expect(events[0]!.intent).toBe("open")
	})

	test("existing paths resolve as paths", async () => {
		const path = `${root}/tasks/task-1`
		const { io, calls } = fake({ existing: [path] })
		expect(await main(["tasks/task-1"], io, env, root)).toBe(0)
		expect(calls[0]).toEqual(["agency", "context", path, "--json"])
	})

	test("epics skip execution preparation", async () => {
		const { io, calls } = fake({ context: context("epic") })
		expect(await main(["epic:epic-1"], io, env, root)).toBe(0)
		expect(calls[0]).toEqual([
			"agency",
			"context",
			"--epic",
			"epic-1",
			"--json",
		])
		expect(calls.some((call) => call[1] === "work")).toBe(false)
		expect(calls.at(-1)).toContain("nvim -- EPIC.md")
	})

	test.each([
		["ABC-42", `${root}/tasks/abc-42-add-thing/TASK.md`],
		[
			"https://example.atlassian.net/browse/abc-7",
			`${root}/tasks/renamed/TASK.md`,
		],
	])("ticket %s matches by ID prefix or ticketUrl", async (target, path) => {
		const { io, calls } = fake()
		expect(await main([target], io, env, root)).toBe(0)
		const list = calls.findIndex((call) => call[1] === "task")
		expect(calls[list]).toEqual(["agency", "task", "list", "--json"])
		expect(calls[list + 1]).toEqual(["agency", "context", path, "--json"])
	})

	test("unknown ticket fails before any tab exists", async () => {
		const { io, calls, events } = fake()
		expect(await main(["ABC-999"], io, env, root)).toBe(1)
		expect(calls.some((call) => call[0] === "herdr")).toBe(false)
		expect(events[0]!.message).toContain(
			"No Agency task matches ticket ABC-999",
		)
		expect(events[0]!.recovery).toBeUndefined()
	})

	test("blocked preparation fails before any tab and hints at the opt-in", async () => {
		const { io, calls, events } = fake({
			prepare: fail("EXECUTION_BLOCKED", "blocked by dep"),
		})
		expect(await main(["task-1"], io, env, root)).toBe(1)
		expect(calls.some((call) => call[0] === "herdr")).toBe(false)
		expect(events[0]).toMatchObject({ event: "error", stage: "preflight" })
		expect(events[0]!.message).toContain("--allow-working-dependencies")
	})

	test("workspace warnings fail preflight", async () => {
		const { io, calls } = fake({
			prepare: ok({
				...preview,
				workspace: { warnings: ["Unable to resolve reference x"] },
			}),
		})
		expect(await main(["task-1"], io, env, root)).toBe(1)
		expect(calls.some((call) => call[0] === "herdr")).toBe(false)
	})

	test("terminal targets and non-ready orchestration are rejected", async () => {
		const terminal = fake({
			context: context("task", "execution", { ready: false, terminal: true }),
		})
		expect(await main(["task-1"], terminal.io, env, root)).toBe(1)
		const epic = fake({
			context: context("epic", "orchestration", {
				ready: false,
				terminal: false,
				blockers: [{ kind: "dependency" }],
			}),
		})
		expect(await main(["epic:epic-1"], epic.io, env, root)).toBe(1)
		expect(epic.calls.some((call) => call[0] === "herdr")).toBe(false)
	})

	test("a worker cannot launch itself", async () => {
		const { io, events } = fake()
		expect(
			await main(
				["task-1"],
				io,
				{ ...env, AGENCY_TARGET: "execution-unit:task/task-1" },
				root,
			),
		).toBe(1)
		expect(events[0]!.message).toContain("cannot launch itself")
	})

	test("forwards the working-dependency opt-in, workbase, and executable", async () => {
		const cli = "/opt/owner's cli"
		const { io, calls } = fake()
		expect(
			await main(
				[
					"task-1",
					"--allow-working-dependencies",
					"--workbase",
					"wb",
					"--agency-executable",
					cli,
				],
				io,
				env,
				root,
			),
		).toBe(0)
		expect(calls[0]).toEqual([
			cli,
			"--workbase",
			"wb",
			"context",
			"task-1",
			"--json",
		])
		expect(calls[1]).toContain("--allow-working-dependencies")
		expect(calls.at(-2)![4]).toStartWith(
			`'/opt/owner'\\''s cli' work . --auto --allow-working-dependencies || `,
		)
	})

	test("rejects invalid executables and missing Herdr environment up front", async () => {
		const bad = fake()
		expect(
			await main(
				["task-1", "--agency-executable", "relative/cli"],
				bad.io,
				env,
				root,
			),
		).toBe(1)
		expect(bad.calls).toEqual([])
		const noHerdr = fake()
		expect(await main(["task-1"], noHerdr.io, {}, root)).toBe(1)
		expect(noHerdr.calls).toEqual([])
	})

	test("reports tab IDs when a later Herdr step fails", async () => {
		const { io, events } = fake()
		const run = io.run
		io.run = async (argv, cwd, timeout) =>
			argv[2] === "split"
				? { status: 1, stdout: "", stderr: '{"error":{"code":"x"}}' }
				: run(argv, cwd, timeout)
		expect(await main(["task-1"], io, env, root)).toBe(1)
		expect(events[0]).toMatchObject({
			stage: "editor-split",
			tabId: "w2:t9",
			workerPaneId: "w2:p1",
		})
		expect(events[0]!.recovery).toBeDefined()
	})

	describe("rex", () => {
		const rexRequest = (call: string[]) => {
			expect(call.slice(0, 7)).toEqual([
				"rex",
				"--autostart=false",
				"api",
				"call",
				"-s",
				"session:s1",
				"session.new_window",
			])
			return JSON.parse(call[7]!) as {
				window_label: string
				focus: boolean
				layout: {
					split: {
						direction: string
						before: { block: { label: string; options: JsonObject } }
						after: { block: { label: string; options: JsonObject } }
					}
				}
			}
		}

		test("creates an unfocused worker/editor tab in one atomic call", async () => {
			const { io, calls, events } = fake()
			expect(await main(["task-1"], io, rexEnv, root)).toBe(0)
			const dir = `${root}/tasks/task-1`
			expect(calls.slice(0, 2)).toEqual([
				["agency", "context", "task-1", "--json"],
				["agency", "work", "prepare", dir, "--dry-run", "--json"],
			])
			expect(calls).toHaveLength(3)
			const request = rexRequest(calls[2]!)
			expect(request.window_label).toBe("task-1")
			expect(request.focus).toBe(false)
			const { split } = request.layout
			expect(split.direction).toBe("horizontal")
			expect(split.before.block.label).toBe("worker")
			expect(split.before.block.options).toEqual({
				cwd: dir,
				initial_input:
					"agency work . --auto || printf '\\033]777;notify;%s;%s\\033\\\\' 'Agency launch failed' 'task-1: agency work exited with an error. See its tab.'\n",
			})
			expect(split.after.block).toMatchObject({
				label: "editor",
				options: { cwd: dir, initial_input: "nvim -- TASK.md\n" },
			})
			expect(events).toEqual([
				{
					event: "launched",
					intent: "launch",
					mux: "rex",
					sessionId: "session:s1",
					target: "task-1",
					kind: "task",
					documentPath: `${dir}/TASK.md`,
					tabId: "window:w9",
					workerPaneId: "block:b1",
					editorPaneId: "block:b2",
				},
			])
		})

		test("failure command emits an OSC 777 desktop notification", () => {
			const { io, calls } = fake()
			return main(["task-1"], io, rexEnv, root).then(() => {
				const input = String(
					rexRequest(calls[2]!).layout.split.before.block.options.initial_input,
				)
				const notify = input.slice(input.indexOf("|| ") + 3).trim()
				const result = Bun.spawnSync(["/bin/zsh", "-fc", notify])
				expect(result.stdout.toString()).toBe(
					"\x1b]777;notify;Agency launch failed;task-1: agency work exited with an error. See its tab.\x1b\\",
				)
			})
		})

		test("passes OPENCODE_CONFIG_CONTENT by wrapping the login shell", async () => {
			const { io, calls } = fake({ context: context("phase") })
			expect(
				await main(
					["task-1/phase-2", "--open"],
					io,
					{ ...rexEnv, OPENCODE_CONFIG_CONTENT: '{"a":1}' },
					root,
				),
			).toBe(0)
			const { split } = rexRequest(calls.at(-1)!).layout
			for (const side of [split.before, split.after])
				expect(side.block.options).toMatchObject({
					shell: "none",
					command: [
						"/usr/bin/env",
						'OPENCODE_CONFIG_CONTENT={"a":1}',
						"/bin/zsh",
						"-l",
					],
				})
			expect(String(split.before.block.options.initial_input)).toStartWith(
				"agency work . || ",
			)
			expect(split.after.block.options.initial_input).toBe("nvim -- PHASE.md\n")
		})

		test("Herdr wins when both are present; --mux overrides", async () => {
			const both = { ...env, ...rexEnv }
			const herdrRun = fake()
			expect(await main(["task-1"], herdrRun.io, both, root)).toBe(0)
			expect(herdrRun.calls.some((call) => call[0] === "rex")).toBe(false)
			expect(herdrRun.events[0]!.mux).toBe("herdr")
			const rexRun = fake()
			expect(
				await main(["task-1", "--mux", "rex"], rexRun.io, both, root),
			).toBe(0)
			expect(rexRun.calls.some((call) => call[0] === "herdr")).toBe(false)
			expect(rexRun.events[0]!.mux).toBe("rex")
		})

		test("rejects a bad --mux and --mux rex without REX_SESSION", async () => {
			const bad = fake()
			expect(
				await main(["task-1", "--mux", "tmux"], bad.io, rexEnv, root),
			).toBe(1)
			expect(bad.calls).toEqual([])
			const missing = fake()
			expect(
				await main(["task-1", "--mux", "rex"], missing.io, env, root),
			).toBe(1)
			expect(missing.calls).toEqual([])
		})

		test("a failed Rex call leaves no tab to recover", async () => {
			const { io, events } = fake({
				rex: { status: 1, stdout: "", stderr: "session_not_found" },
			})
			expect(await main(["task-1"], io, rexEnv, root)).toBe(1)
			expect(events[0]).toMatchObject({
				event: "error",
				stage: "tab-create",
				mux: "rex",
			})
			expect(events[0]!.message).toContain("session_not_found")
			expect(events[0]!.recovery).toBeUndefined()
		})
	})
})
