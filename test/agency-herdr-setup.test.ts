import { describe, expect, test } from "bun:test"
import { spawnSync } from "node:child_process"
import { main, type Runtime } from "../bin/agency-herdr-setup.ts"

type JsonObject = Record<string, unknown>
const env = {
	HERDR_ENV: "1",
	HERDR_WORKSPACE_ID: "w2",
	HERDR_TAB_ID: "w2:t9",
	HERDR_PANE_ID: "w2:p4",
}
const pane = (id: string) => ({
	pane_id: id,
	workspace_id: "w2",
	tab_id: "w2:t9",
})
const ok = (result: unknown) => ({ version: 1, ok: true, result })
const herdr = (type: string, result = {}) => ({
	id: "cli:test",
	result: { type, ...result },
})
const output = (value: unknown, status: number | null = 0) => ({
	status,
	stdout: JSON.stringify(value),
	stderr: "",
})
const failure = (code = "WORKTREE_ERROR") =>
	output(
		{
			version: 1,
			ok: false,
			error: { code, message: "diagnostic", fields: {}, retryable: false },
		},
		1,
	)
const agentFailure = (code: string) => ({
	status: 1,
	stdout: "",
	stderr: JSON.stringify({
		id: "cli:agent:wait",
		error: { code, message: "diagnostic" },
	}),
})

// Fields consumed by the helper, using Agency 3.2.15 / Herdr 0.8.2 wire shapes.
function fixture(kind = "task", container = false) {
	const root = "/work base/owner's project"
	const taskPath = `${root}/tasks/task-1/TASK.md`
	const path =
		kind === "phase"
			? `${root}/tasks/task-1/phases/phase-2/PHASE.md`
			: kind === "epic"
				? `${root}/epics/epic-1/EPIC.md`
				: taskPath
	const directory = path.slice(0, path.lastIndexOf("/"))
	const execution = kind !== "epic" && !container
	const id =
		kind === "phase" ? "phase-2" : kind === "epic" ? "epic-1" : "task-1"
	const data: JsonObject = execution
		? { repo: "repo", branch: "feature/one", base: "main", status: "open" }
		: container
			? { phases: [{ id: "phase-2" }] }
			: { tasks: [{ id: "task-1" }] }
	const doc = { id, path, sha256: "revision-1", data }
	const task =
		kind === "phase"
			? {
					id: "task-1",
					path: taskPath,
					sha256: "parent-revision",
					data: { phases: [{ id: "phase-2" }] } as JsonObject,
				}
			: kind === "task"
				? doc
				: null
	return {
		workbase: { root },
		target: {
			kind,
			archived: false,
			path,
			...(kind !== "epic" ? { taskId: "task-1" } : { epicId: "epic-1" }),
			...(kind === "phase" ? { phaseId: id } : {}),
		},
		documents: {
			task,
			phase: kind === "phase" ? doc : null,
			epic: kind === "epic" ? doc : null,
		},
		authority: {
			mode: execution ? "execution" : "orchestration",
			writable: execution
				? {
						repo: "repo",
						repositoryPath: `${root}/repos/repo`,
						checkoutPath: `${directory}/code/repo`,
						branch: "feature/one",
						base: "main",
					}
				: null,
			references: [] as JsonObject[],
			documents: {
				writable: execution
					? [taskPath, ...(kind === "phase" ? [path] : [])]
					: [],
			},
		},
		graph: {
			aggregate: { status: "open" },
			dependencies: [] as string[],
			readiness: {
				ready: true,
				terminal: false,
				blocked: false,
				blockedBy: [] as string[],
				blockers: [] as JsonObject[],
			},
		},
		validation: { valid: true, warnings: [] as unknown[] },
		workspace: {
			materialization: "complete",
			writable: execution ? { materialized: true, registered: true } : null,
			warnings: [] as string[],
		},
	}
}

type Context = ReturnType<typeof fixture>
function setStatus(context: Context, status: string) {
	context.graph.aggregate.status = status
	context.graph.readiness.ready = false
	context.graph.readiness.terminal = status === "done" || status === "dropped"
	if (context.authority.mode === "execution") {
		const doc = context.documents.phase ?? context.documents.task!
		doc.data.status = status
		doc.sha256 = `revision-${status}`
		context.graph.readiness.blocked = true
		context.graph.readiness.blockedBy = [doc.id]
		context.graph.readiness.blockers = [
			{
				kind: "status",
				id: doc.id,
				status,
				reason: `Target status is ${status}`,
			},
		]
	}
}

function prepare(context: Context, dryRun: boolean) {
	const { target, documents, authority, workbase } = context
	const doc = target.kind === "phase" ? documents.phase! : documents.task!
	const node =
		target.kind === "phase"
			? `execution-unit:phase/task-1/phase-2`
			: "execution-unit:task/task-1"
	const directory = target.path.slice(0, target.path.lastIndexOf("/"))
	return {
		workspace: {
			root: workbase.root,
			taskPath: documents.task!.path,
			phasePath: documents.phase?.path ?? null,
			dryRun,
			writablePath: authority.writable!.checkoutPath,
			reviewPath: null,
			repo: "repo",
			repos: [],
		},
		validation: { valid: true },
		validationEvidence: {
			status: dryRun ? "refreshed" : "reused",
			reasons: dryRun ? ["not-supplied"] : [],
			evidence: {
				version: 1,
				valid: true,
				target: node,
				workbaseRoot: workbase.root,
				documentPath: doc.path,
				documentRevision: doc.sha256,
				digest: "digest",
				workbaseRevision: "workbase-revision",
				configRevision: "config-revision",
				repositoryMappingRevision: "mapping-revision",
				recalledContext: {
					repo: "repo",
					base: "main",
					preferredSlug: "task-1",
					authoritativeSources: [],
				},
			},
		},
		execution: {
			version: 1,
			capability: "agency-execution-v1",
			mode: dryRun ? "preview" : "applied",
			workbaseRoot: workbase.root,
			executionIdentity: { target: node, documentRevision: doc.sha256 },
			workspace: {
				state: dryRun ? "planned" : "materialized",
				executionDirectory: directory,
				taskDocument: documents.task!.path,
				phaseDocument: documents.phase?.path ?? null,
				checkoutPath: authority.writable!.checkoutPath,
			},
		},
	}
}

function blocked(context: Context) {
	context.graph.dependencies = ["previous"]
	context.graph.readiness = {
		ready: false,
		blocked: true,
		terminal: false,
		blockedBy: ["previous"],
		blockers: [
			{
				kind: "dependency",
				id: "previous",
				status: "working",
				reason: `${context.target.kind === "phase" ? "Phase" : "Task"} dependency is working`,
			},
		],
	}
	const graphId =
		context.target.kind === "phase" ? "phase:task-1/previous" : "task:previous"
	return {
		version: 1,
		ok: false,
		error: {
			code: "EXECUTION_BLOCKED",
			retryable: false,
			message: "dependency working",
			fields: {
				action: "work",
				target: prepare(context, true).execution.executionIdentity.target,
				status: "open",
				blockedBy: [graphId],
				blockers: [{ ...context.graph.readiness.blockers[0], id: graphId }],
			},
		},
	}
}

function harness(context = fixture()) {
	const calls: { argv: string[]; cwd: string; timeout: number }[] = []
	const events: JsonObject[] = []
	let clock = 0
	let contexts = 0
	const state = {
		context,
		final: structuredClone(context),
		calls,
		events,
		override: (
			_argv: string[],
			_index: number,
		): ReturnType<typeof output> | undefined => undefined,
		advance: (ms: number) => {
			clock += ms
		},
		io: {} as Runtime,
	}
	state.io = {
		now: () => clock,
		sleep: async (ms) => {
			clock += ms
		},
		emit: (event) => events.push(event),
		run: async (argv, cwd, timeout) => {
			calls.push({ argv, cwd, timeout })
			expect(timeout).toBeGreaterThan(0)
			const overridden = state.override(argv, calls.length - 1)
			if (overridden) return overridden
			if (argv[0] === "agency") {
				if (argv[1] === "context")
					return output(ok(contexts++ === 0 ? state.context : state.final))
				return output(ok(prepare(context, argv.includes("--dry-run"))))
			}
			if (argv[1] === "tab")
				return output(
					herdr("tab_info", { tab: { workspace_id: "w2", tab_id: "w2:t9" } }),
				)
			if (argv[2] === "get")
				return output(herdr("pane_info", { pane: pane("w2:p4") }))
			if (argv[2] === "split")
				return output(
					herdr("pane_info", {
						pane: pane(argv.includes("down") ? "w2:p20" : "w2:p25"),
					}),
				)
			if (argv[1] === "agent")
				return output(
					herdr("agent_info", {
						agent: {
							...pane("w2:p20"),
							agent: "opencode",
							agent_status: argv[5],
						},
					}),
				)
			return output(herdr("ok"))
		},
	}
	return state
}
const run = async (
	h: ReturnType<typeof harness>,
	intent = "launch",
	options: string[] = [],
) => {
	const result = await main(
		[h.context.target.path, "--intent", intent, ...options],
		h.io,
		env,
	)
	// Check outside main: assertions inside the fake runner could be caught as command failures.
	expect(
		h.calls.some(({ argv }) => argv.some((arg) => arg.includes("--force"))),
	).toBe(false)
	return result
}
const commands = (h: ReturnType<typeof harness>) =>
	h.calls.map(({ argv }) => argv.join(" "))
const noClose = (h: ReturnType<typeof harness>) =>
	expect(commands(h).some((c) => c.startsWith("herdr pane close"))).toBe(false)
const contexts = (h: ReturnType<typeof harness>) =>
	h.calls.filter(({ argv }) => argv[1] === "context")

describe("agency-herdr-setup", () => {
	for (const [kind, container] of [
		["task", false],
		["phase", false],
		["task", true],
		["epic", false],
	] as const) {
		for (const intent of ["open", "launch"])
			test(`${kind}${container ? " container" : ""}: ${intent}`, async () => {
				const h = harness(fixture(kind, container))
				expect(await run(h, intent)).toBe(0)
				expect(contexts(h)).toHaveLength(2)
				const preps = h.calls.filter(({ argv }) => argv[2] === "prepare")
				expect(preps).toHaveLength(kind === "epic" || container ? 0 : 2)
				if (preps.length)
					expect(JSON.parse(preps[1]!.argv.at(-1)!)).toEqual(
						prepare(h.context, true).validationEvidence.evidence,
					)
				const list = commands(h)
				expect(list).toContain(
					`herdr pane run w2:p20 agency work .${intent === "launch" ? " --auto" : ""}`,
				)
				expect(
					list
						.filter((c) => c.includes("pane split"))
						.every((c) => c.endsWith("--no-focus")),
				).toBe(true)
				expect(list.findIndex((c) => c.includes("nvim --"))).toBeLessThan(
					list.findIndex((c) => c.includes("agent wait")),
				)
				expect(list.at(-1)).toBe("herdr pane close w2:p4")
				expect(
					h.calls.every(
						(c) =>
							c.cwd ===
							h.context.target.path.slice(
								0,
								h.context.target.path.lastIndexOf("/"),
							),
					),
				).toBe(true)
				expect(h.events.at(-2)?.event).toBe("complete")
			})
	}

	test("quotes and spaces are argv paths, never shell interpolation", async () => {
		const h = harness()
		expect(await run(h)).toBe(0)
		expect(h.calls[0]!.argv[2]).toBe(h.context.target.path)
		expect(
			h.calls.filter((c) => c.argv[2] === "run").map((c) => c.argv[4]),
		).toEqual(["agency work . --auto", "nvim -- 'TASK.md'"])
	})

	for (const bad of [
		{ HERDR_ENV: "0" },
		{ HERDR_WORKSPACE_ID: "" },
		{ HERDR_TAB_ID: "w3:t9" },
		{ HERDR_PANE_ID: "focused" },
		{ HERDR_PANE_ID: "w2:p4;oops" },
		{ AGENCY_SESSION_ID: "session" },
		{ AGENCY_TARGET: "target" },
		{ AGENCY_SESSION_ID: "" },
		{ AGENCY_TARGET: "" },
	])
		test(`reject environment ${JSON.stringify(bad)}`, async () => {
			const h = harness()
			expect(
				await main([h.context.target.path, "--intent", "open"], h.io, {
					...env,
					...bad,
				}),
			).toBe(1)
			expect(h.calls).toHaveLength(0)
		})
	for (const args of [
		[],
		["--intent", "create"],
		["--intent", "launch", "--force", "true"],
		["--intent", "launch", "--force"],
		["--intent", "open", "--intent", "launch"],
		["--intent", "open", "--timeout-ms", "0"],
		["--intent", "open", "--timeout-ms", "300001"],
		["--intent", "open", "--timeout-ms", "1.5"],
	])
		test(`reject arguments ${args.join(" ")}`, async () => {
			const h = harness()
			expect(await main([h.context.target.path, ...args], h.io, env)).toBe(1)
			expect(h.calls).toHaveLength(0)
		})

	test("startup recognition race retries only agent_not_found within one deadline", async () => {
		const h = harness()
		let attempts = 0
		h.override = (argv) =>
			argv[1] === "agent" && attempts++ < 3
				? agentFailure("agent_not_found")
				: undefined
		expect(await run(h)).toBe(0)
		expect(attempts).toBe(4)
		expect(
			h.calls.filter((c) => c.argv[1] === "agent").map((c) => c.timeout),
		).toEqual([60_000, 59_900, 59_800, 59_700])
	})
	test("recognition timeout is bounded and retains setup", async () => {
		const h = harness()
		h.override = (argv) =>
			argv[1] === "agent" ? agentFailure("agent_not_found") : undefined
		expect(await run(h, "launch", ["--timeout-ms", "1000"])).toBe(1)
		expect(h.calls.filter((c) => c.argv[1] === "agent")).toHaveLength(10)
		expect(contexts(h)).toHaveLength(2)
		noClose(h)
	})
	for (const status of ["blocked", "unknown", "idle"])
		test(`launch fails visible on ${status}`, async () => {
			const h = harness()
			h.override = (argv) =>
				argv[1] === "agent"
					? output(
							herdr("agent_info", {
								agent: {
									...pane("w2:p20"),
									agent: "opencode",
									agent_status: status,
								},
							}),
						)
					: undefined
			expect(await run(h)).toBe(1)
			noClose(h)
		})
	for (const code of [
		"timeout",
		"agent_not_running",
		"pane_not_found",
		"transport_failed",
	])
		test(`does not retry ${code}`, async () => {
			const h = harness()
			h.override = (argv) =>
				argv[1] === "agent" ? agentFailure(code) : undefined
			expect(await run(h)).toBe(1)
			expect(h.calls.filter((c) => c.argv[1] === "agent")).toHaveLength(1)
			noClose(h)
		})

	for (const kind of ["task", "phase"])
		for (const intent of ["open", "launch"])
			test(`working dependency blocks without override: ${kind} ${intent}`, async () => {
				const h = harness(fixture(kind))
				const guard = blocked(h.context)
				h.final = structuredClone(h.context)
				h.override = (argv) =>
					argv[2] === "prepare" && argv.includes("--dry-run")
						? output(guard, 1)
						: undefined
				expect(await run(h, intent)).toBe(1)
				const preps = h.calls.filter((c) => c.argv[2] === "prepare")
				expect(preps).toHaveLength(1)
				expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
				expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
				expect(JSON.stringify(h.events)).toContain(
					"Requires readiness-only override; --force also overrides active locks",
				)
				expect(contexts(h)).toHaveLength(2)
				noClose(h)
			})

	for (const mutation of [
		"open dependency",
		"undeclared",
		"validation",
		"missing status",
		"wrong target",
		"wrong code",
		"extra blocker",
		"dirty",
		"invalid context",
	])
		test(`preflight failure never enables override: ${mutation}`, async () => {
			const h = harness(fixture("phase"))
			const guard = blocked(h.context)
			const blocker: JsonObject = guard.error.fields.blockers[0]!
			if (mutation === "open dependency") blocker.status = "open"
			if (mutation === "undeclared") blocker.id = "phase:task-1/other"
			if (mutation === "validation") blocker.kind = "validation"
			if (mutation === "missing status") delete blocker.status
			if (mutation === "wrong target")
				guard.error.fields.target = "execution-unit:task/other"
			if (mutation === "wrong code") guard.error.code = "VALIDATION_FAILED"
			if (mutation === "extra blocker")
				guard.error.fields.blockers.push({ ...blocker, id: "other" })
			if (mutation === "invalid context") h.context.validation.valid = false
			h.override = (argv) =>
				argv[2] === "prepare"
					? mutation === "dirty"
						? failure()
						: output(guard, 1)
					: undefined
			expect(await run(h)).toBe(1)
			expect(h.calls.some((c) => c.argv.includes("--force"))).toBe(false)
			expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
			expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
			expect(contexts(h)).toHaveLength(2)
			noClose(h)
		})

	for (let index = 1; index <= 9; index++)
		test(`failure at step ${index} retains setup and verifies once`, async () => {
			const h = harness()
			h.override = (_argv, i) => (i === index ? failure() : undefined)
			expect(await run(h)).toBe(1)
			expect(contexts(h)).toHaveLength(2)
			noClose(h)
		})

	for (const change of [
		"authority",
		"identity",
		"validation",
		"warnings",
		"materialization",
	])
		test(`final ${change} mismatch retains setup`, async () => {
			const h = harness()
			if (change === "authority")
				h.final.authority.writable!.repositoryPath += "-changed"
			if (change === "identity" && "taskId" in h.final.target)
				h.final.target.taskId = "other"
			if (change === "validation") h.final.validation.valid = false
			if (change === "warnings")
				h.final.workspace.warnings.push("Unable to resolve reference 'missing'")
			if (change === "materialization")
				h.final.workspace.writable!.registered = false
			expect(await run(h)).toBe(1)
			expect(contexts(h)).toHaveLength(2)
			noClose(h)
		})

	for (const value of [
		null,
		{},
		[],
		{ version: 2, ok: true, result: fixture() },
		{ version: 1, ok: true, result: null },
		{ version: 1, ok: false, result: fixture() },
	])
		test(`malformed initial envelope ${JSON.stringify(value)?.slice(0, 40)}`, async () => {
			const h = harness()
			h.override = () => output(value)
			expect(await run(h)).toBe(1)
			expect(h.calls).toHaveLength(1)
		})
	for (const id of ["w3:p20", "w2:p4", "w2:p0", "w2:p20\n", "w2:p20;bad"])
		test(`reject split ID ${JSON.stringify(id)}`, async () => {
			const h = harness()
			h.override = (argv) =>
				argv[2] === "split"
					? output(herdr("pane_info", { pane: pane(id) }))
					: undefined
			expect(await run(h)).toBe(1)
			expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
			noClose(h)
		})
	test("changed evidence after apply prevents launch and builds recovery", async () => {
		const h = harness()
		h.override = (argv) => {
			if (argv[2] !== "prepare" || argv.includes("--dry-run")) return
			const applied = prepare(h.context, false)
			applied.validationEvidence.status = "refreshed"
			return output(ok(applied))
		}
		expect(await run(h)).toBe(1)
		expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
		expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
		noClose(h)
	})
	test("open orchestration must be ready, never prepared or forced", async () => {
		const h = harness(fixture("epic"))
		h.context.graph.readiness.ready = false
		expect(await run(h)).toBe(1)
		expect(h.calls.some((c) => c.argv[2] === "prepare")).toBe(false)
		noClose(h)
	})
	test("extensionless entrypoint runs under Bun without invoking tools", () => {
		const result = spawnSync(
			process.execPath,
			[new URL("../bin/agency-herdr-setup", import.meta.url).pathname],
			{
				env: { ...process.env, HERDR_ENV: "0" },
				encoding: "utf8",
				timeout: 5000,
			},
		)
		expect(result.status).toBe(1)
		expect(JSON.parse(result.stdout).message).toBe("HERDR_ENV=1 is required")
	})
	test("nonzero final context still counts as the single final verification", async () => {
		const h = harness()
		h.override = (_argv, index) => (index === 10 ? failure() : undefined)
		expect(await run(h)).toBe(1)
		expect(contexts(h)).toHaveLength(2)
		noClose(h)
	})
	test("close failure is reported after pre-close completion, never retried", async () => {
		const h = harness()
		h.override = (argv) =>
			argv[2] === "close" ? agentFailure("pane_close_failed") : undefined
		expect(await run(h)).toBe(1)
		expect(h.events.some((event) => event.event === "complete")).toBe(true)
		expect(h.events.at(-1)?.event).toBe("error")
		expect(h.calls.filter((call) => call.argv[2] === "close")).toHaveLength(1)
	})
	for (const stage of ["preview", "apply"])
		for (const defect of [
			"validation",
			"authority",
			"evidence",
			"contract",
			"warnings",
		])
			test(`${stage} rejects ${defect}`, async () => {
				const h = harness()
				h.override = (argv) => {
					if (
						argv[2] !== "prepare" ||
						argv.includes("--dry-run") !== (stage === "preview")
					)
						return
					const result = prepare(h.context, stage === "preview")
					if (defect === "validation") result.validation.valid = false
					if (defect === "authority")
						result.workspace.writablePath = "/other/checkout"
					if (defect === "evidence")
						result.validationEvidence.evidence.target = "other"
					if (defect === "contract") result.execution.version = 2
					if (defect === "warnings")
						Object.assign(result.workspace, {
							warnings: ["Unable to resolve reference 'bad'"],
						})
					return output(ok(result))
				}
				expect(await run(h)).toBe(1)
				expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
				noClose(h)
			})
	for (const value of [
		{},
		{ id: "cli:test", result: { type: "other" } },
		{
			id: "cli:test",
			result: {
				type: "pane_info",
				pane: { ...pane("w2:p4"), tab_id: "w2:t3" },
			},
		},
		{
			id: "cli:test",
			result: { type: "pane_info", pane: pane("w2:p4") },
			error: { code: "error" },
		},
	])
		test(`malformed caller response ${JSON.stringify(value)}`, async () => {
			const h = harness()
			h.override = (argv) => (argv[2] === "get" ? output(value) : undefined)
			expect(await run(h)).toBe(1)
			expect(contexts(h)).toHaveLength(2)
			expect(h.calls).toHaveLength(3)
			noClose(h)
		})
	test("ready orchestration can have blocked descendants", async () => {
		const h = harness(fixture("epic"))
		h.context.graph.readiness.blockers = [
			{
				kind: "dependency",
				id: "later:earlier",
				status: "open",
				reason: "Task 'later' dependency 'earlier' is open",
			},
		]
		expect(await run(h)).toBe(0)
	})
	test("unknown waits to deadline rather than satisfying startup", async () => {
		const h = harness()
		h.override = (argv) => {
			if (argv[1] !== "agent") return
			h.advance(Number(argv.at(-1)))
			return agentFailure("timeout")
		}
		expect(await run(h)).toBe(1)
		noClose(h)
	})
	test("editor time consumes the same detection budget", async () => {
		const h = harness()
		h.override = (argv) => {
			if (argv[4]?.startsWith("nvim")) h.advance(60_001)
			return undefined
		}
		expect(await run(h)).toBe(1)
		expect(h.calls.some((c) => c.argv[1] === "agent")).toBe(false)
		noClose(h)
	})
	test("only exact missing writable branch warning is tolerated", async () => {
		const h = harness()
		h.context.workspace.warnings = [
			`Unable to resolve branch 'feature/one' in ${h.context.authority.writable!.repositoryPath}`,
		]
		expect(await run(h)).toBe(0)
	})
	test("spawn timeout diagnostics survive recovery", async () => {
		const h = harness()
		h.override = (argv) =>
			argv[2] === "prepare"
				? { status: null, stdout: "", stderr: "spawnSync agency ETIMEDOUT" }
				: undefined
		expect(await run(h)).toBe(1)
		expect(JSON.stringify(h.events)).toContain("ETIMEDOUT")
		expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
		noClose(h)
	})
	test("installed Agency IDs allow dots", async () => {
		const h = harness(
			JSON.parse(
				JSON.stringify(fixture("epic")).replaceAll("epic-1", "epic.1"),
			),
		)
		expect(await run(h)).toBe(0)
		expect(commands(h)).toContain("herdr tab rename w2:t9 epic.1")
	})
	test("non-readiness preflight diagnostics are retained verbatim", async () => {
		const h = harness()
		h.override = (argv) =>
			argv[2] === "prepare" ? failure("DIRTY_WORKTREE") : undefined
		expect(await run(h)).toBe(1)
		expect(JSON.stringify(h.events)).toContain("DIRTY_WORKTREE")
		noClose(h)
	})
	test("contradictory execution readiness is not trusted", async () => {
		const h = harness()
		h.context.documents.task!.data.status = "working"
		expect(await run(h)).toBe(1)
		expect(h.calls).toHaveLength(1)
	})
	test("final claim status and revision may change without changing authority", async () => {
		const h = harness()
		setStatus(h.final, "working")
		expect(await run(h)).toBe(0)
	})

	for (const [kind, container] of [
		["task", false],
		["phase", false],
		["task", true],
		["epic", false],
	] as const) {
		for (const intent of ["open", "launch"])
			test(`resume working ${kind} container=${container}: ${intent}`, async () => {
				const h = harness(fixture(kind, container))
				setStatus(h.context, "working")
				h.final = structuredClone(h.context)
				expect(await run(h, intent)).toBe(0)
				expect(h.calls.filter((c) => c.argv[2] === "prepare")).toHaveLength(
					container || kind === "epic" ? 0 : 2,
				)
			})
		for (const status of ["done", "dropped"]) {
			test(`reject initially ${status} ${kind} container=${container}`, async () => {
				const h = harness(fixture(kind, container))
				setStatus(h.context, status)
				h.final = structuredClone(h.context)
				expect(await run(h)).toBe(1)
				expect(h.calls.some((c) => c.argv[2] === "prepare")).toBe(false)
				expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
				noClose(h)
			})
			test(`worker rapidly ${status} ${kind} container=${container}`, async () => {
				const h = harness(fixture(kind, container))
				setStatus(h.final, status)
				h.override = (argv) =>
					argv[1] === "agent"
						? output(
								herdr("agent_info", {
									agent: {
										...pane("w2:p20"),
										agent: "opencode",
										agent_status: "done",
									},
								}),
							)
						: undefined
				expect(await run(h)).toBe(0)
				expect(contexts(h)).toHaveLength(2)
			})
		}
	}
	for (const container of [false, true])
		test(`working orchestration allows non-validation blockers: container=${container}`, async () => {
			const h = harness(fixture(container ? "task" : "epic", container))
			setStatus(h.context, "working")
			h.context.graph.readiness.blockers = [
				{
					kind: "dependency",
					id: "later:previous",
					status: "open",
					reason: "Dependency is open",
				},
			]
			expect(await run(h)).toBe(0)
		})
	for (const kind of ["task", "epic"])
		test(`working ${kind} still rejects validation blockers`, async () => {
			const h = harness(fixture(kind))
			setStatus(h.context, "working")
			h.context.graph.readiness.blockers.push({
				kind: "validation",
				id: "doc",
				reason: "Invalid document",
			})
			expect(await run(h)).toBe(1)
			expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
			noClose(h)
		})
	test("working execution still defers refusal to unforced preparation", async () => {
		const h = harness()
		setStatus(h.context, "working")
		h.override = (argv) =>
			argv[2] === "prepare" ? failure("WORKTREE_LOCK_ERROR") : undefined
		expect(await run(h)).toBe(1)
		expect(h.calls.filter((c) => c.argv[2] === "prepare")).toHaveLength(1)
		expect(JSON.stringify(h.events)).toContain("WORKTREE_LOCK_ERROR")
		noClose(h)
	})
	test("working execution can resume with dependency blockers when unforced prepare permits it", async () => {
		const h = harness()
		setStatus(h.context, "working")
		h.context.graph.readiness.blockers.push({
			kind: "dependency",
			id: "previous",
			status: "open",
			reason: "Task dependency is open",
		})
		h.final = structuredClone(h.context)
		expect(await run(h)).toBe(0)
		expect(h.calls.filter((c) => c.argv[2] === "prepare")).toHaveLength(2)
	})
	for (const defect of ["validation", "authority", "materialization"])
		test(`rapid completion still checks ${defect}`, async () => {
			const h = harness()
			setStatus(h.final, "done")
			if (defect === "validation") h.final.validation.valid = false
			if (defect === "authority")
				h.final.authority.writable!.repositoryPath += "-changed"
			if (defect === "materialization")
				h.final.workspace.writable!.registered = false
			expect(await run(h)).toBe(1)
			noClose(h)
		})

	for (const kind of ["branch", "base"]) {
		for (const refused of [false, true])
			test(`provisional declared ${kind}: prepare refusal=${refused}`, async () => {
				const h = harness()
				const writable = h.context.authority.writable!
				h.context.workspace.warnings = [
					`Unable to resolve ${kind} '${kind === "base" ? writable.base : writable.branch}' in ${writable.repositoryPath}`,
				]
				h.override = (argv) =>
					refused && argv[2] === "prepare"
						? failure("REMOTE_REF_NOT_FOUND")
						: undefined
				expect(await run(h)).toBe(refused ? 1 : 0)
				expect(h.calls.filter((c) => c.argv[2] === "prepare")).toHaveLength(
					refused ? 1 : 2,
				)
				if (refused) noClose(h)
			})
		test(`final declared ${kind} warning is never provisional`, async () => {
			const h = harness()
			const writable = h.final.authority.writable!
			h.final.workspace.warnings = [
				`Unable to resolve ${kind} '${kind === "base" ? writable.base : writable.branch}' in ${writable.repositoryPath}`,
			]
			expect(await run(h)).toBe(1)
			noClose(h)
		})
	}
	for (const warning of [
		"Unable to resolve reference 'main' in /work base/owner's project/repos/repo",
		"Unable to resolve base 'other' in /work base/owner's project/repos/repo",
		"Unable to resolve base 'main' in /other/repo",
		"Unable to resolve branch 'other' in /work base/owner's project/repos/repo",
		"Unable to resolve branch 'feature/one' in /other/repo",
		"Unable to inspect checkout /work base/owner's project/code/repo",
	])
		test(`never broaden provisional warnings: ${warning}`, async () => {
			const h = harness()
			h.context.workspace.warnings = [warning]
			expect(await run(h)).toBe(1)
			expect(h.calls.some((c) => c.argv[2] === "prepare")).toBe(false)
			expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
			noClose(h)
		})
})
