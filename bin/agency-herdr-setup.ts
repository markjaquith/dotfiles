import { spawnSync } from "node:child_process"
import { accessSync, constants, statSync, writeSync } from "node:fs"
import { basename, dirname, isAbsolute, join, resolve } from "node:path"
import { isDeepStrictEqual } from "node:util"

type ObjectValue = Record<string, unknown>
const readinessOverrideWarning =
	"Requires readiness-only override; --force also overrides active locks. Automatic override is disabled."
type Output = { status: number | null; stdout: string; stderr: string }
export type Runtime = {
	run: (argv: string[], cwd: string, timeout: number) => Promise<Output>
	emit: (event: ObjectValue) => void
	now: () => number
	sleep: (ms: number) => Promise<void>
}

const runtime: Runtime = {
	async run(argv, cwd, timeout) {
		const result = spawnSync(argv[0]!, argv.slice(1), {
			cwd,
			encoding: "utf8",
			stdio: ["ignore", "pipe", "pipe"],
			timeout,
			maxBuffer: 8 * 1024 * 1024,
		})
		return {
			status: result.status,
			stdout: result.stdout ?? "",
			stderr: [result.stderr, result.error?.message].filter(Boolean).join("\n"),
		}
	},
	emit: (event) => {
		writeSync(1, `${JSON.stringify(event)}\n`)
	},
	now: () => performance.now(),
	sleep: (ms) => new Promise((done) => setTimeout(done, ms)),
}

function requireValue(condition: unknown, message: string): asserts condition {
	if (!condition) throw new Error(message)
}

function object(value: unknown): ObjectValue {
	requireValue(
		value !== null && typeof value === "object" && !Array.isArray(value),
		"Expected JSON object",
	)
	return value as ObjectValue
}

function text(value: unknown): string {
	requireValue(
		typeof value === "string" &&
			value.length > 0 &&
			!/[\x00-\x1f\x7f]/.test(value),
		"Expected nonempty text without control characters",
	)
	return value
}

function array(value: unknown): unknown[] {
	requireValue(Array.isArray(value), "Expected JSON array")
	return value
}

function absolute(value: unknown): string {
	const path = text(value)
	requireValue(
		isAbsolute(path) && resolve(path) === path,
		`Expected canonical absolute path: ${path}`,
	)
	return path
}

function slug(value: unknown): string {
	const id = text(value)
	requireValue(
		/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(id),
		`Invalid Agency ID: ${id}`,
	)
	return id
}

function inspect(value: unknown, documentPath: string) {
	const context = object(value)
	const target = object(context.target)
	const documents = object(context.documents)
	const kind = text(target.kind)
	requireValue(
		["task", "phase", "epic"].includes(kind),
		`Unsupported target: ${kind}`,
	)
	requireValue(
		target.path === documentPath && target.archived === false,
		"Target path mismatch or archived target",
	)
	const root = absolute(object(context.workbase).root)
	const doc = object(documents[kind])
	const id = slug(target[`${kind}Id`])
	const taskId = kind === "epic" ? undefined : slug(target.taskId)
	const expectedPath =
		kind === "epic"
			? join(root, "epics", id, "EPIC.md")
			: kind === "phase"
				? join(root, "tasks", taskId!, "phases", id, "PHASE.md")
				: join(root, "tasks", id, "TASK.md")
	requireValue(
		documentPath === expectedPath && doc.id === id && doc.path === documentPath,
		"Document identity mismatch",
	)
	text(doc.sha256)
	const data = object(doc.data)
	const authority = object(context.authority)
	const execution = authority.mode === "execution"
	const orchestration =
		kind === "epic" || (kind === "task" && Array.isArray(data.phases))
	requireValue(
		execution !== orchestration &&
			authority.mode === (orchestration ? "orchestration" : "execution"),
		"Unsupported or inconsistent authority mode",
	)
	const directory = dirname(documentPath)
	if (kind !== "epic") {
		const task = object(documents.task)
		requireValue(
			task.id === taskId &&
				task.path === join(root, "tasks", taskId!, "TASK.md"),
			"Parent task identity mismatch",
		)
	}
	const writableDocuments = execution
		? [object(documents.task).path, ...(kind === "phase" ? [documentPath] : [])]
		: []
	requireValue(
		isDeepStrictEqual(
			array(object(authority.documents).writable),
			writableDocuments,
		),
		"Unexpected document write authority",
	)
	let writable: ObjectValue | null = null
	if (execution) {
		writable = object(authority.writable)
		const repo = slug(data.repo)
		requireValue(
			writable.repo === repo &&
				writable.checkoutPath === join(directory, "code", repo) &&
				writable.branch === text(data.branch) &&
				writable.base === text(data.base),
			"Unexpected write authority",
		)
		absolute(writable.repositoryPath)
	} else
		requireValue(
			authority.writable === null,
			"Orchestration cannot have write authority",
		)
	for (const entry of array(authority.references)) {
		const reference = object(entry)
		const repo = slug(reference.repo)
		text(reference.ref)
		absolute(reference.repositoryPath)
		requireValue(
			reference.checkoutPath === join(directory, "code", repo) &&
				reference.checkoutPath !== writable?.checkoutPath,
			"Unexpected reference authority",
		)
	}
	const graph = object(context.graph)
	const status = text(execution ? data.status : object(graph.aggregate).status)
	requireValue(
		["open", "working", "delegated", "done", "dropped"].includes(status),
		"Unknown target status",
	)
	const readiness = object(graph.readiness)
	requireValue(
		typeof readiness.ready === "boolean" &&
			typeof readiness.terminal === "boolean" &&
			typeof readiness.blocked === "boolean",
		"Malformed readiness",
	)
	const blockers = array(readiness.blockers).map(object)
	if (execution) {
		requireValue(
			readiness.ready === (status === "open" && blockers.length === 0) &&
				readiness.terminal === (status === "done" || status === "dropped"),
			"Inconsistent execution readiness",
		)
	}
	for (const blocker of blockers) {
		requireValue(
			["dependency", "status", "validation"].includes(text(blocker.kind)),
			"Unknown blocker kind",
		)
		text(blocker.id)
		text(blocker.reason)
	}
	const validation = object(context.validation)
	const workspace = object(context.workspace)
	array(validation.warnings)
	const warnings = array(workspace.warnings).map(text)
	const node =
		kind === "phase"
			? `execution-unit:phase/${taskId}/${id}`
			: `execution-unit:task/${id}`
	return {
		context,
		target,
		documents,
		doc,
		root,
		id,
		taskId,
		kind,
		directory,
		execution,
		authority,
		writable,
		readiness,
		status,
		blockers,
		validation,
		warnings,
		node,
	}
}

type Context = ReturnType<typeof inspect>

function clean(context: Context, provisional = false) {
	requireValue(
		context.validation.valid === true &&
			array(context.validation.warnings).length === 0 &&
			!context.blockers.some((blocker) => blocker.kind === "validation"),
		"Context validation is not clean",
	)
	// Unforced preparation resolves new branches and fetches declared remote bases.
	const writable = context.writable
	const expected =
		provisional && writable
			? ["branch", "base"].map(
					(kind) =>
						`Unable to resolve ${kind} '${writable[kind]}' in ${writable.repositoryPath}`,
				)
			: []
	requireValue(
		context.warnings.every((warning) => expected.includes(warning)),
		`Unsafe workspace warnings: ${JSON.stringify(context.warnings)}`,
	)
}

function prepared(
	value: unknown,
	context: Context,
	dryRun: boolean,
	previous?: ObjectValue,
) {
	const result = object(value)
	requireValue(
		object(result.validation).valid === true,
		"Preparation validation failed",
	)
	const issues = object(result.validation).issues
	requireValue(
		issues === undefined || array(issues).length === 0,
		"Preparation validation issues",
	)
	const workspace = object(result.workspace)
	const contract = object(result.execution)
	const contractWorkspace = object(contract.workspace)
	const identity = object(contract.executionIdentity)
	const disposition = object(result.validationEvidence)
	const evidence = object(disposition.evidence)
	requireValue(
		!("warnings" in workspace) || array(workspace.warnings).length === 0,
		"Preparation workspace warnings",
	)
	requireValue(
		isDeepStrictEqual(
			array(workspace.repos),
			array(context.authority.references).map((entry) => {
				const reference = object(entry)
				return { repo: reference.repo, ref: reference.ref }
			}),
		),
		"Preparation reference authority changed",
	)
	requireValue(
		workspace.root === context.root &&
			workspace.taskPath === object(context.documents.task).path &&
			workspace.phasePath ===
				(context.kind === "phase" ? context.doc.path : null) &&
			workspace.dryRun === dryRun &&
			workspace.writablePath === context.writable?.checkoutPath &&
			workspace.repo === context.writable?.repo &&
			workspace.reviewPath === null,
		"Preparation workspace changed authority or identity",
	)
	requireValue(
		contract.version === 1 &&
			contract.capability === "agency-execution-v1" &&
			contract.mode === (dryRun ? "preview" : "applied") &&
			contract.workbaseRoot === context.root &&
			identity.target === context.node &&
			identity.documentRevision === context.doc.sha256 &&
			contractWorkspace.executionDirectory === context.directory &&
			contractWorkspace.checkoutPath === context.writable?.checkoutPath &&
			contractWorkspace.taskDocument === workspace.taskPath &&
			contractWorkspace.phaseDocument === workspace.phasePath &&
			contractWorkspace.state === (dryRun ? "planned" : "materialized"),
		"Invalid execution contract",
	)
	requireValue(
		evidence.version === 1 &&
			evidence.valid === true &&
			evidence.target === context.node &&
			evidence.workbaseRoot === context.root &&
			evidence.documentPath === context.doc.path &&
			evidence.documentRevision === context.doc.sha256,
		"Invalid validation evidence identity",
	)
	for (const key of [
		"digest",
		"workbaseRevision",
		"configRevision",
		"repositoryMappingRevision",
	])
		text(evidence[key])
	const recalled = object(evidence.recalledContext)
	requireValue(
		recalled.repo === context.writable?.repo &&
			recalled.base === context.writable?.base &&
			recalled.preferredSlug === context.taskId,
		"Evidence recalled authority mismatch",
	)
	array(recalled.authoritativeSources).map(text)
	if (previous)
		requireValue(
			disposition.status === "reused" &&
				array(disposition.reasons).length === 0 &&
				isDeepStrictEqual(previous, evidence),
			"Validation evidence changed during preparation",
		)
	else
		requireValue(
			["reused", "refreshed"].includes(text(disposition.status)),
			"Unknown evidence disposition",
		)
	return evidence
}

async function notifyFailure(
	io: Runtime,
	env: NodeJS.ProcessEnv,
	ids: ObjectValue,
	message: string,
) {
	const origin = [
		env.AGENCY_HERDR_ORIGIN_PANE_ID,
		env.AGENCY_HERDR_ORIGIN_TAB_ID,
		env.AGENCY_HERDR_ORIGIN_WORKSPACE_ID,
	]
	if (origin.every((value) => value === undefined)) return
	try {
		const [originPaneId, originTabId, originWorkspaceId] = origin.map(text)
		requireValue(
			!originPaneId!.startsWith("-") &&
				originPaneId !== env.HERDR_PANE_ID &&
				originTabId !== env.HERDR_TAB_ID &&
				(!env.HERDR_WORKSPACE_ID ||
					originWorkspaceId === env.HERDR_WORKSPACE_ID),
			"Invalid notification origin",
		)
		// Inherit this process's Herdr session; never target the UI-focused session.
		const call = async (args: string[], type: string) => {
			const output = await io.run(["herdr", ...args], process.cwd(), 15_000)
			const envelope = object(
				JSON.parse(output.stdout.trim() || output.stderr.trim()),
			)
			const result = object(envelope.result)
			requireValue(
				output.status === 0 &&
					envelope.error === undefined &&
					envelope.ok !== false &&
					text(envelope.id) &&
					result.type === type,
				`herdr ${args.slice(0, 2).join(" ")} failed`,
			)
			return result
		}
		const info = object(
			(await call(["pane", "get", originPaneId!], "pane_info")).pane,
		)
		requireValue(
			info.pane_id === originPaneId &&
				info.tab_id === originTabId &&
				info.workspace_id === originWorkspaceId,
			"Notification origin no longer matches live pane metadata",
		)
		// Keep raw command/context diagnostics in the setup pane, not the toast.
		const summary = message.split(/[\r\n{\[]/, 1)[0]!.slice(0, 200)
		const setup = [env.HERDR_PANE_ID, env.HERDR_TAB_ID, env.HERDR_WORKSPACE_ID]
			.map((value) => value?.replace(/[\x00-\x1f\x7f]/g, " ") || "unknown")
			.join(" / ")
		const body = `Origin ${originPaneId} (${originTabId}, ${originWorkspaceId}); failed setup ${setup}. ${summary} See setup diagnostics; do not rerun blindly.`
		const notification = await call(
			[
				"notification",
				"show",
				"Agency setup failed",
				"--body",
				body,
				"--sound",
				"request",
			],
			"notification_show",
		)
		requireValue(
			notification.shown === true && notification.reason === "shown",
			`Herdr did not show notification: ${text(notification.reason)}`,
		)
		io.emit({
			event: "failure-notification",
			originPaneId,
			originTabId,
			originWorkspaceId,
			...ids,
		})
	} catch (error) {
		io.emit({
			event: "diagnostic",
			message: `Failure notification not delivered: ${error instanceof Error ? error.message : String(error)}`,
			...ids,
		})
	}
}

export async function main(
	args: string[],
	io: Runtime = runtime,
	env: NodeJS.ProcessEnv = process.env,
): Promise<number> {
	const errors: string[] = []
	const ids: ObjectValue = {}
	const record = (error: unknown) => {
		const message = error instanceof Error ? error.message : String(error)
		errors.push(message)
		io.emit({ event: "error", message, ...ids })
	}
	try {
		requireValue(env.HERDR_ENV === "1", "HERDR_ENV=1 is required")
		requireValue(
			env.AGENCY_SESSION_ID === undefined && env.AGENCY_TARGET === undefined,
			"Active Agency workers cannot run setup",
		)
		const workspaceId = text(env.HERDR_WORKSPACE_ID)
		const tabId = text(env.HERDR_TAB_ID)
		const setupId = text(env.HERDR_PANE_ID)
		// Herdr IDs are opaque; verify their relationships against live metadata below.
		Object.assign(ids, { workspaceId, tabId, setupId })
		let documentPath: string | undefined
		let intent: string | undefined
		let timeout = 60_000
		let prepareTimeout = 300_000
		let agency = "agency"
		let allowWorkingDependencies = false
		const seen = new Set<string>()
		for (let i = 0; i < args.length; i++) {
			const option = text(args[i])
			if (!option.startsWith("-")) {
				requireValue(documentPath === undefined, "Expected one document path")
				documentPath = absolute(option)
				continue
			}
			requireValue(!seen.has(option), `Duplicate option: ${option}`)
			seen.add(option)
			if (option === "--allow-working-dependencies") {
				allowWorkingDependencies = true
				continue
			}
			requireValue(
				[
					"--intent",
					"--timeout-ms",
					"--prepare-timeout-ms",
					"--agency-executable",
				].includes(option),
				`Unknown option: ${option}`,
			)
			const value = args[++i]
			requireValue(
				value !== undefined && !value.startsWith("-"),
				`Missing value for ${option}`,
			)
			text(value)
			if (option === "--intent") intent = value
			else if (option === "--timeout-ms" || option === "--prepare-timeout-ms") {
				requireValue(/^\d+$/.test(value), "Timeout must be an integer")
				if (option === "--timeout-ms") timeout = Number(value)
				else prepareTimeout = Number(value)
			} else agency = absolute(value)
		}
		requireValue(
			documentPath !== undefined,
			"Absolute document path is required",
		)
		requireValue(
			intent === "open" || intent === "launch",
			"Explicit --intent open|launch is required",
		)
		requireValue(
			timeout >= 1_000 && timeout <= 300_000,
			"--timeout-ms range is 1000..300000",
		)
		requireValue(
			prepareTimeout >= 1_000 && prepareTimeout <= 600_000,
			"--prepare-timeout-ms range is 1000..600000",
		)
		if (agency !== "agency") {
			try {
				requireValue(statSync(agency).isFile(), "Not a regular file")
				accessSync(agency, constants.X_OK)
			} catch (error) {
				throw new Error(
					`Invalid --agency-executable ${agency}: ${error instanceof Error ? error.message : String(error)}`,
				)
			}
		}
		const permission = allowWorkingDependencies
			? ["--allow-working-dependencies"]
			: []
		const cwd = dirname(documentPath)
		const call = async (argv: string[], limit = 120_000) => {
			io.emit({
				event: "command",
				argv: argv.includes("--evidence")
					? argv
							.slice(0, argv.indexOf("--evidence"))
							.concat("--evidence", "<validated JSON>")
					: argv,
				...ids,
			})
			const output = await io.run(argv, cwd, limit)
			// Herdr's send_ok_request commands deliberately print nothing on success.
			if (
				argv[0] === "herdr" &&
				argv[1] === "pane" &&
				["run", "close"].includes(argv[2]!) &&
				output.status === 0 &&
				!output.stdout.trim() &&
				!output.stderr.trim()
			) {
				const result: ObjectValue = { type: "ok" }
				return { failed: false as const, result, envelope: { result }, output }
			}
			let envelope: ObjectValue
			try {
				envelope = object(
					JSON.parse(output.stdout.trim() || output.stderr.trim()),
				)
			} catch {
				throw new Error(
					`Invalid JSON from ${argv.slice(0, 3).join(" ")}: ${JSON.stringify(output)}`,
				)
			}
			if (
				output.status !== 0 ||
				envelope.error !== undefined ||
				envelope.ok === false
			) {
				io.emit({ event: "diagnostic", ...output, ...ids })
			}
			requireValue(
				!(envelope.result !== undefined && envelope.error !== undefined),
				"Ambiguous success/error envelope",
			)
			if (argv[0] === agency)
				requireValue(
					envelope.version === 1 && typeof envelope.ok === "boolean",
					"Invalid Agency envelope",
				)
			else text(envelope.id)
			if (
				output.status !== 0 ||
				envelope.error !== undefined ||
				envelope.ok === false
			) {
				return { failed: true as const, envelope, output }
			}
			return {
				failed: false as const,
				result: object(envelope.result),
				envelope,
				output,
			}
		}
		const success = (response: Awaited<ReturnType<typeof call>>) => {
			if (response.failed) {
				const error = response.envelope.error
				const code =
					error && typeof error === "object" && "code" in error
						? String(error.code)
						: "unknown"
				throw new Error(
					`Command failed (${code}): ${JSON.stringify(response.output)}`,
				)
			}
			return response.result
		}
		const herdr = async (args: string[], type: string) => {
			const result = success(await call(["herdr", ...args], 15_000))
			requireValue(
				result.type === type,
				`Unexpected Herdr result type: ${result.type}`,
			)
			return result
		}
		const pane = (value: unknown, expected?: string) => {
			const info = object(value)
			const id = text(info.pane_id)
			requireValue(
				info.workspace_id === workspaceId &&
					info.tab_id === tabId &&
					(!expected || id === expected),
				"Unexpected pane identity or location",
			)
			return id
		}
		const initial = inspect(
			success(await call([agency, "context", documentPath, "--json"])),
			documentPath,
		)
		ids.targetId =
			initial.kind === "phase" ? `${initial.taskId}/${initial.id}` : initial.id
		// Without trusted identity there is no safe recovery layout. Always verify once after inspection.
		let worker: string | undefined
		let launched = false
		let deadline = 0
		try {
			pane((await herdr(["pane", "get", setupId], "pane_info")).pane, setupId)
			if (allowWorkingDependencies) {
				try {
					const unsupported: string[] = []
					for (const command of [["work", "prepare"], ["work"]]) {
						const argv = [agency, ...command, "--help"]
						io.emit({ event: "command", argv, ...ids })
						const help = await io.run(argv, cwd, 15_000)
						if (
							help.status !== 0 ||
							!/^\s*--allow-working-dependencies(?=\s|$)/m.test(help.stdout)
						)
							unsupported.push(command.join(" "))
					}
					requireValue(
						unsupported.length === 0,
						`${agency}: --allow-working-dependencies is not advertised by ${unsupported.map((command) => `${command} --help`).join(" and ")}. Use a verified supporting Agency executable; preparation and worker launch were not attempted.`,
					)
				} catch (error) {
					record(error)
				}
			}
			const renamed = object(
				(
					await herdr(
						["tab", "rename", tabId, String(ids.targetId)],
						"tab_info",
					)
				).tab,
			)
			requireValue(
				renamed.tab_id === tabId && renamed.workspace_id === workspaceId,
				"Tab rename identity mismatch",
			)
			if (errors.length === 0)
				try {
					clean(initial, true)
					requireValue(
						initial.readiness.terminal === false,
						"Terminal work is not launchable",
					)
					if (initial.execution) {
						const preview = await call([
							agency,
							"work",
							"prepare",
							initial.directory,
							"--dry-run",
							"--json",
							...permission,
						])
						if (
							preview.failed &&
							object(preview.envelope.error).code === "EXECUTION_BLOCKED"
						) {
							throw new Error(
								`Preparation blocked: ${JSON.stringify(preview.output)}. ${readinessOverrideWarning}`,
							)
						}
						const evidence = prepared(success(preview), initial, true)
						const applied = success(
							await call(
								[
									agency,
									"work",
									"prepare",
									initial.directory,
									"--json",
									...permission,
									"--evidence",
									JSON.stringify(evidence),
								],
								prepareTimeout,
							),
						)
						prepared(applied, initial, false, evidence)
					} else
						requireValue(
							initial.readiness.ready === true || initial.status === "working",
							`Orchestration target not ready or resumable: ${JSON.stringify(initial.readiness)}. ${readinessOverrideWarning}`,
						)
				} catch (error) {
					record(error)
				}
			const workerOpenCodeConfig =
				env.AGENCY_HERDR_WORKER_OPENCODE_CONFIG_CONTENT
			if (workerOpenCodeConfig !== undefined) {
				requireValue(
					!workerOpenCodeConfig.includes("\0"),
					"Invalid inherited worker OpenCode configuration",
				)
				object(JSON.parse(workerOpenCodeConfig))
			}
			worker = pane(
				(
					await herdr(
						[
							"pane",
							"split",
							"--pane",
							setupId,
							"--direction",
							"down",
							"--cwd",
							initial.directory,
							...(workerOpenCodeConfig === undefined
								? []
								: ["--env", `OPENCODE_CONFIG_CONTENT=${workerOpenCodeConfig}`]),
							"--no-focus",
						],
						"pane_info",
					)
				).pane,
			)
			requireValue(worker !== setupId, "Worker ID reused setup pane")
			ids.workerId = worker
			if (errors.length === 0) {
				try {
					await herdr(
						[
							"pane",
							"run",
							worker,
							`${agency === "agency" ? agency : `'${agency.replaceAll("'", "'\\''")}'`} work .${intent === "launch" ? " --auto" : ""}${allowWorkingDependencies ? " --allow-working-dependencies" : ""}`,
						],
						"ok",
					)
					launched = true
					deadline = io.now() + timeout
				} catch (error) {
					record(error)
				}
			}
			const editor = pane(
				(
					await herdr(
						[
							"pane",
							"split",
							"--pane",
							worker,
							"--direction",
							"right",
							"--cwd",
							initial.directory,
							"--no-focus",
						],
						"pane_info",
					)
				).pane,
			)
			requireValue(
				editor !== setupId && editor !== worker,
				"Editor ID reused existing pane",
			)
			ids.editorId = editor
			await herdr(
				["pane", "run", editor, `nvim -- '${basename(documentPath)}'`],
				"ok",
			)
			if (launched) {
				const expected = intent === "launch" ? "working" : "idle"
				for (;;) {
					const remaining = Math.floor(deadline - io.now())
					requireValue(remaining > 0, "Worker detection deadline exceeded")
					const response = await call(
						[
							"herdr",
							"agent",
							"wait",
							worker,
							"--until",
							expected,
							"--until",
							"done",
							"--until",
							"blocked",
							"--timeout",
							String(remaining),
						],
						remaining,
					)
					if (response.failed) {
						const error = object(response.envelope.error)
						if (
							response.output.status === 1 &&
							error.code === "agent_not_found" &&
							typeof error.message === "string"
						) {
							await io.sleep(Math.min(100, Math.max(0, deadline - io.now())))
							continue
						}
						throw new Error(
							`Worker detection failed: ${JSON.stringify(response.output)}`,
						)
					}
					requireValue(
						response.result.type === "agent_info",
						"Malformed agent wait response",
					)
					const agent = object(response.result.agent)
					pane(agent, worker)
					text(agent.agent)
					requireValue(
						agent.agent_status === expected || agent.agent_status === "done",
						`Worker state is ${agent.agent_status}; setup retained`,
					)
					break
				}
			}
		} catch (error) {
			record(error)
		}
		try {
			const final = inspect(
				success(await call([agency, "context", documentPath, "--json"])),
				documentPath,
			)
			clean(final)
			requireValue(
				isDeepStrictEqual(initial.target, final.target) &&
					initial.root === final.root &&
					isDeepStrictEqual(initial.authority, final.authority),
				"Final context identity or authority changed",
			)
			if (launched && initial.execution) {
				const workspace = object(final.context.workspace)
				requireValue(
					workspace.materialization === "complete" &&
						object(workspace.writable).materialized === true &&
						object(workspace.writable).registered === true,
					"Final execution workspace is not materialized and registered",
				)
			}
		} catch (error) {
			record(error)
		}
		if (errors.length) return 1
		io.emit({
			event: "complete",
			...ids,
			intent,
			message: "Setup verified; closing temporary setup pane",
		})
		await herdr(["pane", "close", setupId], "ok")
		return 0
	} catch (error) {
		record(error)
		return 1
	} finally {
		if (errors.length) await notifyFailure(io, env, ids, errors[0]!)
	}
}
