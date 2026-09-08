import { afterAll, beforeAll, describe, expect, test } from "bun:test"
import { spawnSync } from "node:child_process"
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { main, type Runtime } from "../bin/agency-herdr-setup.ts"

type JsonObject = Record<string, unknown>
const env = {
	HERDR_ENV: "1",
	HERDR_WORKSPACE_ID: "w2",
	HERDR_TAB_ID: "w2:t9",
	HERDR_PANE_ID: "w2:p4",
}
const originEnv = {
	...env,
	AGENCY_HERDR_ORIGIN_PANE_ID: "w2:pOrigin",
	AGENCY_HERDR_ORIGIN_TAB_ID: "w2:tOrigin",
	AGENCY_HERDR_ORIGIN_WORKSPACE_ID: "w2",
}
const flag = "--allow-working-dependencies"
let executableDirectory: string
let executable: string
let nonExecutable: string
beforeAll(() => {
	executableDirectory = mkdtempSync(join(tmpdir(), "agency-setup-test-"))
	executable = join(executableDirectory, "owner's $source cli.ts")
	nonExecutable = join(executableDirectory, "not-executable.ts")
	for (const file of [executable, nonExecutable])
		writeFileSync(
			file,
			'#!/usr/bin/env bun\nthrow new Error("Must not execute")\n',
		)
	chmodSync(executable, 0o755)
	chmodSync(nonExecutable, 0o644)
})
afterAll(() => rmSync(executableDirectory, { recursive: true, force: true }))
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
			if (argv[0] === "agency" || argv[0] === executable) {
				if (argv.includes("--help"))
					return {
						status: 0,
						stdout: `Options:\n  ${flag}  Allow working dependencies\n`,
						stderr: "",
					}
				if (argv[1] === "context")
					return output(ok(contexts++ === 0 ? state.context : state.final))
				return output(ok(prepare(context, argv.includes("--dry-run"))))
			}
			if (argv[1] === "tab")
				return output(
					herdr("tab_info", { tab: { workspace_id: "w2", tab_id: "w2:t9" } }),
				)
			if (argv[2] === "get")
				return output(
					herdr("pane_info", {
						pane:
							argv[3] === originEnv.AGENCY_HERDR_ORIGIN_PANE_ID
								? {
										...pane(argv[3]),
										tab_id: originEnv.AGENCY_HERDR_ORIGIN_TAB_ID,
									}
								: pane("w2:p4"),
					}),
				)
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
			if (argv[1] === "notification")
				return output(
					herdr("notification_show", { shown: true, reason: "shown" }),
				)
			return { status: 0, stdout: "", stderr: "" }
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
	for (const prepareTimeout of [undefined, 1000, 450000, 600000])
		for (const intent of ["open", "launch"])
			test(`separate apply budget: ${prepareTimeout ?? "default"}, ${intent}`, async () => {
				const h = harness()
				expect(
					await run(h, intent, [
						flag,
						...(prepareTimeout === undefined
							? []
							: ["--prepare-timeout-ms", String(prepareTimeout)]),
					]),
				).toBe(0)
				expect(contexts(h).map(({ timeout }) => timeout)).toEqual([
					120_000, 120_000,
				])
				const preps = h.calls.filter(
					({ argv }) => argv[2] === "prepare" && !argv.includes("--help"),
				)
				expect(preps.map(({ timeout }) => timeout)).toEqual([
					120_000,
					prepareTimeout ?? 300_000,
				])
				expect(preps[0]!.argv).toContain("--dry-run")
				expect(preps[1]!.argv).toContain("--evidence")
				expect(
					h.calls.filter(({ argv }) => argv.includes("--help")),
				).toHaveLength(2)
				for (const { argv, timeout } of h.calls) {
					if (
						argv.includes("--help") ||
						(argv[0] === "herdr" && argv[1] !== "agent")
					)
						expect(timeout).toBe(15_000)
					if (argv[1] === "agent") expect(timeout).toBe(60_000)
					expect(argv).not.toContain("--prepare-timeout-ms")
				}
				// No clock advancement or sleeps are needed for successful immediate IO.
				expect(h.io.now()).toBe(0)
			})
	test("restores inherited OpenCode config only on the worker pane", async () => {
		const h = harness()
		const workerConfig = JSON.stringify({
			default_agent: "implementation",
		})
		expect(
			await main([h.context.target.path, "--intent", "launch"], h.io, {
				...env,
				AGENCY_HERDR_WORKER_OPENCODE_CONFIG_CONTENT: workerConfig,
			}),
		).toBe(0)
		const splits = h.calls.filter(({ argv }) => argv[2] === "split")
		expect(splits[0]!.argv).toContain("down")
		expect(splits[0]!.argv).toContain("--no-focus")
		expect(splits[0]!.argv).toContain("--env")
		expect(splits[0]!.argv).toContain(`OPENCODE_CONFIG_CONTENT=${workerConfig}`)
		expect(splits[1]!.argv).not.toContain("--env")
	})
	test("prepare and startup overrides are independent and can precede the path", async () => {
		const h = harness()
		expect(
			await main(
				[
					"--prepare-timeout-ms",
					"600000",
					"--timeout-ms",
					"300000",
					h.context.target.path,
					"--intent",
					"launch",
				],
				h.io,
				env,
			),
		).toBe(0)
		expect(
			h.calls.find(({ argv }) => argv.includes("--evidence"))!.timeout,
		).toBe(600_000)
		expect(h.calls.find(({ argv }) => argv[1] === "agent")!.timeout).toBe(
			300_000,
		)
		expect(contexts(h).map(({ timeout }) => timeout)).toEqual([
			120_000, 120_000,
		])
	})
	for (const options of [
		["--prepare-timeout-ms"],
		["--prepare-timeout-ms", "--timeout-ms", "1000"],
		["--prepare-timeout-ms", "300000", "--prepare-timeout-ms", "300000"],
		...[
			"",
			"0",
			"999",
			"600001",
			"-1000",
			"1.5",
			"3e5",
			"NaN",
			"Infinity",
			"300000ms",
			"300000\n",
		].map((value) => ["--prepare-timeout-ms", value]),
	])
		test(`reject invalid prepare timeout before subprocesses: ${JSON.stringify(options)}`, async () => {
			const h = harness()
			expect(await run(h, "open", options)).toBe(1)
			expect(h.calls).toHaveLength(0)
		})

	for (const intent of ["open", "launch"])
		for (const before of [true, false])
			for (const selected of [true, false])
				test(`explicit permission and executable: ${intent}, before=${before}, selected=${selected}`, async () => {
					const h = harness(fixture("phase"))
					blocked(h.context)
					h.final = structuredClone(h.context)
					const options = [
						flag,
						...(selected ? ["--agency-executable", executable] : []),
						"--intent",
						intent,
					]
					const args = before
						? [...options, h.context.target.path]
						: [h.context.target.path, ...options]
					expect(await main(args, h.io, env)).toBe(0)
					const agency = selected ? executable : "agency"
					const agencyCalls = h.calls.filter(({ argv }) => argv[0] !== "herdr")
					expect(agencyCalls.every(({ argv }) => argv[0] === agency)).toBe(true)
					expect(
						agencyCalls
							.filter(({ argv }) => argv.includes("--help"))
							.map(({ argv }) => argv),
					).toEqual([
						[agency, "work", "prepare", "--help"],
						[agency, "work", "--help"],
					])
					const preps = agencyCalls.filter(
						({ argv }) => argv[2] === "prepare" && !argv.includes("--help"),
					)
					expect(
						preps.map(({ argv }) => argv.filter((arg) => arg === flag)),
					).toEqual([[flag], [flag]])
					expect(JSON.parse(preps[1]!.argv.at(-1)!)).toEqual(
						prepare(h.context, true).validationEvidence.evidence,
					)
					const launch = h.calls.find(
						({ argv }) => argv[2] === "run" && argv[3] === "w2:p20",
					)!.argv[4]!
					const expected = [
						agency,
						"work",
						".",
						...(intent === "launch" ? ["--auto"] : []),
						flag,
					]
					// Parse shell words without invoking the executable or any live CLI.
					const parsed = spawnSync(
						"/bin/sh",
						["-c", `set -- ${launch}; printf '%s\\n' "$@"`],
						{ encoding: "utf8" },
					)
					expect(parsed.status).toBe(0)
					expect(parsed.stdout.trimEnd().split("\n")).toEqual(expected)
					if (selected)
						expect(
							launch.startsWith(
								`'${executable.replaceAll("'", "'\\''")}' work .`,
							),
						).toBe(true)
					expect(
						h.calls.some(({ argv }) =>
							argv.some((arg) => arg.includes("--force")),
						),
					).toBe(false)
					expect(contexts(h).every(({ argv }) => !argv.includes(flag))).toBe(
						true,
					)
				})

	for (const selected of [false, true])
		test(`default permission never runs capability probes, selected=${selected}`, async () => {
			const h = harness()
			expect(
				await run(
					h,
					"open",
					selected ? ["--agency-executable", executable] : [],
				),
			).toBe(0)
			expect(
				h.calls.some(
					({ argv }) => argv.includes("--help") || argv.includes(flag),
				),
			).toBe(false)
			expect(
				h.calls
					.filter(({ argv }) => argv[0] !== "herdr")
					.every(({ argv }) => argv[0] === (selected ? executable : "agency")),
			).toBe(true)
		})

	for (const badHelp of [
		"Options:\n  --force  Override readiness",
		`Options:\n  ${flag}-unsafe  Unsupported lookalike`,
		`Options:\n  ${flag}=true`,
		`Do not use ${flag}; unsupported`,
		`Options:\n  --no${flag}  Another lookalike`,
	])
		for (const unsupported of ["prepare", "work"])
			test(`exact option advertisement required: ${unsupported} ${badHelp}`, async () => {
				const h = harness()
				h.override = (argv) =>
					argv.includes("--help") &&
					(argv[2] === "prepare" ? "prepare" : "work") === unsupported
						? { status: 0, stdout: badHelp, stderr: "" }
						: undefined
				expect(await run(h, "launch", [flag])).toBe(1)
				expect(
					h.calls.filter(({ argv }) => argv.includes("--help")),
				).toHaveLength(2)
				expect(
					h.calls.some(
						({ argv }) => argv[2] === "prepare" && !argv.includes("--help"),
					),
				).toBe(false)
				expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
				expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
				expect(JSON.stringify(h.events)).toContain(`${unsupported} --help`)
				expect(JSON.stringify(h.events)).toContain("is not advertised")
				const firstMutation = h.calls.findIndex(({ argv }) => argv[1] === "tab")
				expect(
					h.calls.findLastIndex(({ argv }) => argv.includes("--help")),
				).toBeLessThan(firstMutation)
				expect(contexts(h)).toHaveLength(2)
				noClose(h)
			})
	for (const status of [1, null])
		test(`failed capability command is not support: ${status}`, async () => {
			const h = harness()
			h.override = (argv) =>
				argv.includes("--help")
					? { status, stdout: `  ${flag}  Permit`, stderr: "failed" }
					: undefined
			expect(await run(h, "launch", [flag])).toBe(1)
			expect(
				h.calls.filter(({ argv }) => argv.includes("--help")),
			).toHaveLength(2)
			expect(
				h.calls.some(
					({ argv }) => argv[2] === "prepare" && !argv.includes("--help"),
				),
			).toBe(false)
			noClose(h)
		})
	for (const permitted of [false, true])
		test(`evidence and contract suggestions never grant permission: explicit=${permitted}`, async () => {
			const h = harness()
			const evidence = {
				...prepare(h.context, true).validationEvidence.evidence,
				allowWorkingDependencies: true,
			}
			h.override = (argv) => {
				if (argv[2] !== "prepare" || argv.includes("--help")) return
				const result = prepare(h.context, argv.includes("--dry-run"))
				result.validationEvidence.evidence = evidence
				Object.assign(result.execution, {
					commands: { work: { argv: ["agency", "work", ".", "--auto", flag] } },
				})
				return output(ok(result))
			}
			expect(await run(h, "launch", permitted ? [flag] : [])).toBe(0)
			const applied = h.calls.find(({ argv }) =>
				argv.includes("--evidence"),
			)!.argv
			expect(JSON.parse(applied.at(-1)!)).toEqual(evidence)
			expect(applied.includes(flag)).toBe(permitted)
			const launch = h.calls.find(
				({ argv }) => argv[2] === "run" && argv[3] === "w2:p20",
			)!.argv[4]!
			expect(launch.includes(flag)).toBe(permitted)
		})
	for (const args of [
		["--agency-executable"],
		["--agency-executable", "--intent", "open"],
		["--agency-executable", "relative/cli.ts"],
		["--agency-executable", "/tmp/../cli.ts"],
		["--agency-executable", "/tmp/cli.ts\n"],
		["--agency-executable", "/tmp/cli.ts\0"],
		["--agency-executable", "-option"],
		["--agency-executable", "/bin/sh", "--agency-executable", "/bin/sh"],
		[flag, flag],
		[flag, "true"],
		[flag, "false"],
		[`${flag}=true`],
	])
		for (const before of [false, true])
			test(`reject invalid new options ${JSON.stringify(args)} before=${before}`, async () => {
				const h = harness()
				const base = [h.context.target.path, "--intent", "open"]
				expect(
					await main(
						before ? [...args, ...base] : [...base, ...args],
						h.io,
						env,
					),
				).toBe(1)
				expect(h.calls).toHaveLength(0)
			})
	test("executable must exist, be a file and have actual execute permission before any CLI invocation", async () => {
		for (const path of [
			nonExecutable,
			executableDirectory,
			join(executableDirectory, "missing"),
		]) {
			const h = harness()
			expect(await run(h, "open", ["--agency-executable", path, flag])).toBe(1)
			expect(h.calls).toHaveLength(0)
			expect(JSON.stringify(h.events)).toContain("Invalid --agency-executable")
		}
	})

	for (const stage of [
		"args",
		"env",
		"initial",
		"prepare",
		"final",
		"close",
		"multiple",
	])
		test(`one origin notification after ${stage} failure without input or focus`, async () => {
			const h = harness()
			if (stage === "final" || stage === "multiple")
				h.final.validation.valid = false
			h.override = (argv, index) =>
				(stage === "initial" && index === 0) ||
				((stage === "prepare" || stage === "multiple") &&
					argv[2] === "prepare") ||
				(stage === "close" && argv[2] === "close")
					? argv[0] === "herdr"
						? agentFailure("ORIGINAL_FAILURE")
						: failure("ORIGINAL_FAILURE")
					: undefined
			expect(
				await main(
					stage === "args" ? [] : [h.context.target.path, "--intent", "open"],
					h.io,
					{ ...originEnv, ...(stage === "env" ? { HERDR_ENV: "0" } : {}) },
				),
			).toBe(1)
			const notifications = h.calls.filter(
				({ argv }) => argv[1] === "notification",
			)
			expect(notifications).toHaveLength(1)
			const argv = notifications[0]!.argv
			expect(argv.slice(0, 5)).toEqual([
				"herdr",
				"notification",
				"show",
				"Agency setup failed",
				"--body",
			])
			expect(argv.slice(6)).toEqual(["--sound", "request"])
			expect(argv[5]).toContain(originEnv.AGENCY_HERDR_ORIGIN_PANE_ID)
			for (const id of Object.values(env).slice(1))
				expect(argv[5]).toContain(id)
			expect(argv[5]!.length).toBeLessThan(600)
			if (stage === "initial" || stage === "prepare" || stage === "close")
				expect(argv[5]).toContain("ORIGINAL_FAILURE")
			expect(h.calls.at(-2)!.argv).toEqual([
				"herdr",
				"pane",
				"get",
				originEnv.AGENCY_HERDR_ORIGIN_PANE_ID,
			])
			expect(
				h.events.filter((e) => e.event === "error").length,
			).toBeGreaterThan(0)
			expect(
				h.events.filter((e) => e.event === "failure-notification"),
			).toHaveLength(1)
			expect(
				h.calls.some(({ argv }) =>
					["focus", "prompt", "input", "send-text", "send-keys"].includes(
						argv[2]!,
					),
				),
			).toBe(false)
			expect(
				h.calls.filter(({ argv }) =>
					argv.includes(originEnv.AGENCY_HERDR_ORIGIN_PANE_ID),
				),
			).toHaveLength(1)
		})
	for (const defect of [
		"missing",
		"empty",
		"option",
		"control",
		"wrong workspace",
		"wrong tab",
		"wrong pane",
		"same pane",
		"gone",
		"malformed",
	])
		test(`no notification to unverified origin: ${defect}`, async () => {
			const h = harness()
			const origin: NodeJS.ProcessEnv = { ...originEnv }
			if (defect === "missing") delete origin.AGENCY_HERDR_ORIGIN_TAB_ID
			if (defect === "empty") origin.AGENCY_HERDR_ORIGIN_PANE_ID = ""
			if (defect === "option") origin.AGENCY_HERDR_ORIGIN_PANE_ID = "--current"
			if (defect === "control") origin.AGENCY_HERDR_ORIGIN_PANE_ID += "\n"
			if (defect === "same pane")
				origin.AGENCY_HERDR_ORIGIN_PANE_ID = env.HERDR_PANE_ID
			h.override = (argv) => {
				if (argv[2] !== "get") return
				if (defect === "gone") return agentFailure("pane_not_found")
				if (defect === "malformed") return output({})
				const info = {
					...pane(originEnv.AGENCY_HERDR_ORIGIN_PANE_ID),
					tab_id: originEnv.AGENCY_HERDR_ORIGIN_TAB_ID,
				}
				if (defect === "wrong workspace") info.workspace_id = "wOther"
				if (defect === "wrong tab") info.tab_id = "w2:tOther"
				if (defect === "wrong pane") info.pane_id = "w2:pOther"
				return output(herdr("pane_info", { pane: info }))
			}
			expect(await main([], h.io, origin)).toBe(1)
			expect(h.calls.some(({ argv }) => argv[1] === "notification")).toBe(false)
			expect(
				h.calls.every(({ argv }) => argv[1] === "pane" && argv[2] === "get"),
			).toBe(true)
			expect(h.events.at(-1)?.message).toContain(
				"Failure notification not delivered",
			)
		})
	for (const failureMode of [
		"exit",
		"json",
		"throw",
		"disabled",
		"rate_limited",
		"no_foreground_client",
		"busy",
	])
		test(`notification ${failureMode} failure preserves original error`, async () => {
			const h = harness()
			h.override = (argv) => {
				if (argv[1] !== "notification") return
				if (failureMode === "throw") throw new Error("transport failed")
				if (!["exit", "json"].includes(failureMode))
					return output(
						herdr("notification_show", { shown: false, reason: failureMode }),
					)
				return failureMode === "exit"
					? agentFailure("notification_failed")
					: { status: 0, stdout: "not-json", stderr: "" }
			}
			expect(await main([], h.io, originEnv)).toBe(1)
			expect(
				h.calls.filter(({ argv }) => argv[1] === "notification"),
			).toHaveLength(1)
			expect(h.events.filter((e) => e.event === "error")).toEqual([
				{
					event: "error",
					message: "Absolute document path is required",
					workspaceId: "w2",
					tabId: "w2:t9",
					setupId: "w2:p4",
				},
			])
			expect(h.events.at(-1)?.message).toContain(
				"Failure notification not delivered",
			)
		})
	for (const badEnv of [
		{ HERDR_WORKSPACE_ID: "" },
		{ HERDR_PANE_ID: "" },
		{ HERDR_TAB_ID: "" },
		{ AGENCY_SESSION_ID: "active" },
	])
		test(`early environment failure still verifies origin: ${JSON.stringify(badEnv)}`, async () => {
			const h = harness()
			expect(await main([], h.io, { ...originEnv, ...badEnv })).toBe(1)
			expect(h.calls.map(({ argv }) => argv.slice(1, 3))).toEqual([
				["pane", "get"],
				["notification", "show"],
			])
			expect(h.events.filter((e) => e.event === "error")).toHaveLength(1)
		})
	test("no origin calls on success or default direct failure", async () => {
		const h = harness()
		expect(
			await main(
				[h.context.target.path, "--intent", "launch"],
				h.io,
				originEnv,
			),
		).toBe(0)
		expect(
			h.calls.some(
				({ argv }) =>
					argv[1] === "notification" ||
					argv.includes(originEnv.AGENCY_HERDR_ORIGIN_PANE_ID),
			),
		).toBe(false)
		const failed = harness()
		expect(await main([], failed.io, env)).toBe(1)
		expect(failed.calls).toHaveLength(0)
	})
	test.skipIf(process.env.AGENCY_HERDR_LIVE_CONTRACT !== "1")(
		"installed Agency help remains fail-closed without advertised support (read-only)",
		async () => {
			const help = new Map(
				["prepare", "work"].map((kind) => {
					const result = spawnSync(
						"agency",
						["work", ...(kind === "prepare" ? ["prepare"] : []), "--help"],
						{ encoding: "utf8", timeout: 15_000 },
					)
					return [
						kind,
						{
							status: result.status,
							stdout: result.stdout ?? "",
							stderr: result.stderr ?? "",
						},
					]
				}),
			)
			const h = harness()
			h.override = (argv) =>
				argv.includes("--help")
					? help.get(argv[2] === "prepare" ? "prepare" : "work")
					: undefined
			const supported = [...help.values()].every(
				(result) =>
					result.status === 0 &&
					/^\s*--allow-working-dependencies(?=\s|$)/m.test(result.stdout),
			)
			expect(await run(h, "launch", [flag])).toBe(supported ? 0 : 1)
			expect(
				h.calls.some(
					({ argv }) => argv[2] === "prepare" && !argv.includes("--help"),
				),
			).toBe(supported)
		},
	)

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
	for (const bad of [
		{ HERDR_TAB_ID: "w3:t9" },
		{ HERDR_PANE_ID: "focused" },
		{ HERDR_PANE_ID: "w2:p4;oops" },
	])
		test(`reject caller metadata mismatch ${JSON.stringify(bad)}`, async () => {
			const h = harness()
			expect(
				await main([h.context.target.path, "--intent", "open"], h.io, {
					...env,
					...bad,
				}),
			).toBe(1)
			expect(
				h.calls
					.filter(({ argv }) => argv[0] === "herdr")
					.map(({ argv }) => argv[2]),
			).toEqual(["get"])
		})

	test("accepts opaque IDs from the round-5 live Herdr contract", async () => {
		const h = harness()
		const ids = new Map([
			["w2", "w3S"],
			["w2:t9", "w3S:t21"],
			["w2:p4", "w3S:p48"],
			["w2:p20", "w3S:p4A"],
			["w2:p25", "w3S:p4B"],
		])
		const baseRun = h.io.run
		const liveCalls: string[][] = []
		h.io.run = async (argv, cwd, timeout) => {
			liveCalls.push(argv)
			const result = await baseRun(
				argv.map(
					(arg) => [...ids].find(([, value]) => value === arg)?.[0] ?? arg,
				),
				cwd,
				timeout,
			)
			return {
				...result,
				stdout: result.stdout
					? JSON.stringify(
							JSON.parse(result.stdout),
							(_key, value) => ids.get(value) ?? value,
						)
					: "",
			}
		}
		expect(
			await main([h.context.target.path, "--intent", "launch"], h.io, {
				HERDR_ENV: "1",
				HERDR_WORKSPACE_ID: "w3S",
				HERDR_TAB_ID: "w3S:t21",
				HERDR_PANE_ID: "w3S:p48",
			}),
		).toBe(0)
		expect(liveCalls.at(-1)).toEqual(["herdr", "pane", "close", "w3S:p48"])
		expect(
			liveCalls.some((argv) => argv[2] === "run" && argv[3] === "w3S:p4A"),
		).toBe(true)
	})
	test.skipIf(process.env.AGENCY_HERDR_LIVE_CONTRACT !== "1")(
		"accepts the installed Herdr caller metadata (read-only smoke test)",
		async () => {
			expect(process.env.HERDR_ENV).toBe("1")
			const actual = spawnSync(
				"herdr",
				["pane", "get", process.env.HERDR_PANE_ID!],
				{ encoding: "utf8" },
			)
			expect(actual.status).toBe(0)
			const h = harness()
			h.override = (argv) => {
				if (argv[0] !== "herdr") return undefined
				if (argv[1] === "pane" && argv[2] === "get")
					return { status: 0, stdout: actual.stdout, stderr: "" }
				// All mutations remain simulated; reaching rename proves caller verification passed.
				return agentFailure("smoke_test_stop")
			}
			expect(
				await main(
					[h.context.target.path, "--intent", "open"],
					h.io,
					process.env,
				),
			).toBe(1)
			expect(
				h.calls.some(({ argv }) => argv[1] === "tab" && argv[2] === "rename"),
			).toBe(true)
		},
	)
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
	for (const id of ["", "w2:p4", "w2:p20\n"])
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
	test("rejects split panes belonging to a different workspace or tab", async () => {
		for (const foreign of [
			{ workspace_id: "w3S", tab_id: "w3S:t21", pane_id: "w3S:p48" },
			{ workspace_id: "w2", tab_id: "w2:tOther", pane_id: "w2:pOther" },
		]) {
			const h = harness()
			h.override = (argv) =>
				argv[2] === "split"
					? output(herdr("pane_info", { pane: foreign }))
					: undefined
			expect(await run(h)).toBe(1)
			expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
			noClose(h)
		}
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
				env: {
					...process.env,
					HERDR_ENV: "0",
					AGENCY_HERDR_ORIGIN_PANE_ID: undefined,
					AGENCY_HERDR_ORIGIN_TAB_ID: undefined,
					AGENCY_HERDR_ORIGIN_WORKSPACE_ID: undefined,
				},
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
	for (const stage of ["preview", "apply"])
		test(`${stage} timeout preserves recovery, final verification and one notification`, async () => {
			const h = harness()
			h.override = (argv, index) => {
				if (
					argv[2] !== "prepare" ||
					argv.includes("--dry-run") !== (stage === "preview")
				)
					return
				h.advance(h.calls[index]!.timeout)
				return {
					status: null,
					stdout: "",
					stderr: "spawnSync agency ETIMEDOUT",
				}
			}
			expect(
				await main(
					[h.context.target.path, "--intent", "launch"],
					h.io,
					originEnv,
				),
			).toBe(1)
			expect(h.io.now()).toBe(stage === "preview" ? 120_000 : 300_000)
			expect(JSON.stringify(h.events)).toContain("ETIMEDOUT")
			expect(commands(h).some((c) => c.includes("nvim --"))).toBe(true)
			expect(commands(h).some((c) => c.includes("agency work ."))).toBe(false)
			expect(h.calls.filter(({ argv }) => argv[2] === "prepare")).toHaveLength(
				stage === "preview" ? 1 : 2,
			)
			expect(contexts(h).map(({ timeout }) => timeout)).toEqual([
				120_000, 120_000,
			])
			expect(
				h.calls
					.slice(-2)
					.map(({ argv, timeout }) => [argv[1], argv[2], timeout]),
			).toEqual([
				["pane", "get", 15_000],
				["notification", "show", 15_000],
			])
			expect(
				h.events.filter((event) => event.event === "failure-notification"),
			).toHaveLength(1)
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
