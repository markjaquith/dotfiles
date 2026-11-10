import { spawnSync } from "node:child_process"
import { accessSync, constants, existsSync, statSync, writeSync } from "node:fs"
import { basename, dirname, isAbsolute, resolve } from "node:path"

type ObjectValue = Record<string, unknown>
type Output = { status: number | null; stdout: string; stderr: string }
export type Runtime = {
	run: (argv: string[], cwd: string, timeout: number) => Promise<Output>
	emit: (event: ObjectValue) => void
	exists: (path: string) => boolean
	checkExecutable: (path: string) => void
}

const runtime: Runtime = {
	async run(argv, cwd, timeout) {
		const result = spawnSync(argv[0]!, argv.slice(1), {
			cwd,
			encoding: "utf8",
			stdio: ["ignore", "pipe", "pipe"],
			timeout,
			killSignal: "SIGKILL",
			maxBuffer: 16 * 1024 * 1024,
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
	exists: existsSync,
	checkExecutable(path) {
		requireValue(statSync(path).isFile(), "Not a regular file")
		accessSync(path, constants.X_OK)
	},
}

const usage = `Usage: agency-kickoff <target> [--open] [--allow-working-dependencies]
                      [--workbase <selector>] [--agency-executable <path>]
                      [--mux herdr|rex]

<target> is a task ID, task/phase, epic:<id>, an Agency document or directory
path, or a ticket key/URL matched against existing Agency tasks.

The tab opens in Herdr when HERDR_ENV=1, otherwise in Rex when REX_SESSION is
set. --mux overrides the detection.`

type Mux = "herdr" | "rex"

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
			value.trim().length > 0 &&
			!/[\x00-\x1f\x7f]/.test(value),
		"Expected nonempty text without control characters",
	)
	return value
}

function shellQuote(value: string): string {
	return /^[A-Za-z0-9_./:=@%+-]+$/.test(value)
		? value
		: `'${value.replaceAll("'", "'\\''")}'`
}

const ticketKeyPattern = /[A-Za-z][A-Za-z0-9]+-\d+/

function ticketKey(value: string): string | undefined {
	if (/^https?:\/\//.test(value)) {
		const segments = new URL(value).pathname.split("/").reverse()
		const segment = segments.find((part) =>
			new RegExp(`^${ticketKeyPattern.source}$`).test(part),
		)
		return segment?.toUpperCase()
	}
	return new RegExp(`^${ticketKeyPattern.source}$`).test(value)
		? value.toUpperCase()
		: undefined
}

type Options = {
	target: string
	intent: "open" | "launch"
	allowWorkingDependencies: boolean
	workbase?: string
	agency: string
	mux?: Mux
}

function parse(args: string[]): Options {
	let target: string | undefined
	let intent: Options["intent"] = "launch"
	let allowWorkingDependencies = false
	let workbase: string | undefined
	let agency = "agency"
	let mux: Mux | undefined
	const seen = new Set<string>()
	for (let i = 0; i < args.length; i++) {
		const arg = args[i]!
		if (!arg.startsWith("--")) {
			requireValue(target === undefined, `Unexpected argument: ${arg}`)
			target = text(arg)
			continue
		}
		requireValue(!seen.has(arg), `Duplicate option: ${arg}`)
		seen.add(arg)
		if (arg === "--open") intent = "open"
		else if (arg === "--allow-working-dependencies")
			allowWorkingDependencies = true
		else if (
			arg === "--workbase" ||
			arg === "--agency-executable" ||
			arg === "--mux"
		) {
			const value = args[++i]
			requireValue(
				value !== undefined && !value.startsWith("--"),
				`Missing value for ${arg}`,
			)
			if (arg === "--workbase") workbase = text(value)
			else if (arg === "--mux") {
				requireValue(
					value === "herdr" || value === "rex",
					`--mux must be herdr or rex, not ${JSON.stringify(value)}`,
				)
				mux = value
			} else agency = text(value)
		} else throw new Error(`Unknown option: ${arg}\n${usage}`)
	}
	requireValue(target !== undefined, `A target is required\n${usage}`)
	return { target, intent, allowWorkingDependencies, workbase, agency, mux }
}

function detectMux(options: Options, env: NodeJS.ProcessEnv): Mux {
	if (options.mux) return options.mux
	// A Herdr pane inside a Rex terminal sees both; the innermost (Herdr) wins.
	if (env.HERDR_ENV === "1") return "herdr"
	if (env.REX_SESSION) return "rex"
	throw new Error(
		"Run inside Herdr (HERDR_ENV=1) or Rex (REX_SESSION), or pass --mux",
	)
}

export async function main(
	args: string[],
	io: Runtime = runtime,
	env: NodeJS.ProcessEnv = process.env,
	cwd = process.cwd(),
): Promise<number> {
	const ids: ObjectValue = {}
	let stage = "arguments"
	try {
		if (args.includes("--help") || args.includes("-h")) {
			writeSync(1, `${usage}\n`)
			return 0
		}
		const options = parse(args)
		const { agency } = options
		if (agency !== "agency") {
			try {
				requireValue(
					isAbsolute(agency) && resolve(agency) === agency,
					"Expected normalized absolute path",
				)
				io.checkExecutable(agency)
			} catch (error) {
				throw new Error(
					`Invalid --agency-executable ${JSON.stringify(agency)}: ${error instanceof Error ? error.message : String(error)}`,
				)
			}
		}
		const mux = detectMux(options, env)
		ids.mux = mux
		if (mux === "herdr") {
			requireValue(env.HERDR_ENV === "1", "HERDR_ENV=1 is required")
			ids.workspaceId = text(env.HERDR_WORKSPACE_ID)
		} else {
			requireValue(env.REX_SESSION, "REX_SESSION is required")
			ids.sessionId = text(env.REX_SESSION)
		}

		const agencyCall = async (argv: string[], timeout = 30_000) => {
			const full = [
				agency,
				...(options.workbase ? ["--workbase", options.workbase] : []),
				...argv,
			]
			const output = await io.run(full, cwd, timeout)
			let envelope: ObjectValue
			try {
				envelope = object(JSON.parse(output.stdout.trim()))
			} catch {
				throw new Error(
					`Invalid JSON from ${full.join(" ")}: ${(output.stderr || output.stdout).trim()}`,
				)
			}
			if (output.status !== 0 || envelope.ok !== true) {
				const error =
					envelope.error && typeof envelope.error === "object"
						? (envelope.error as ObjectValue)
						: {}
				const code = typeof error.code === "string" ? error.code : "UNKNOWN"
				const message =
					typeof error.message === "string"
						? error.message
						: (output.stderr || output.stdout).trim()
				throw Object.assign(
					new Error(`${argv[0]} failed (${code}): ${message}`),
					{
						code,
					},
				)
			}
			return envelope.result
		}

		stage = "resolve"
		const { target } = options
		const key = ticketKey(target)
		const byTicket = async (key: string) => {
			const tasks = (await agencyCall(["task", "list", "--json"])) as unknown
			requireValue(Array.isArray(tasks), "Unexpected task list result")
			const matches = tasks.map(object).filter((task) => {
				const id = String(task.id).toUpperCase()
				const url = object(task.data ?? {}).ticketUrl
				return (
					id === key ||
					id.startsWith(`${key}-`) ||
					(typeof url === "string" && ticketKey(url) === key)
				)
			})
			requireValue(
				matches.length > 0,
				`No Agency task matches ticket ${key}. Create the task first, then rerun agency-kickoff with its ID.`,
			)
			requireValue(
				matches.length === 1,
				`Ticket ${key} matches multiple Agency tasks: ${matches.map((task) => task.id).join(", ")}`,
			)
			return text(matches[0]!.path)
		}
		const contextOf = async (...selector: string[]) =>
			object(await agencyCall(["context", ...selector, "--json"]))
		const asPath = resolve(cwd, target)
		let context: ObjectValue
		if (target === "." || target.startsWith("/") || io.exists(asPath)) {
			context = await contextOf(asPath)
		} else if (target.startsWith("epic:")) {
			context = await contextOf("--epic", text(target.slice(5)))
		} else if (/^[^/]+\/[^/]+$/.test(target)) {
			const [taskId, phaseId] = target.split("/")
			context = await contextOf("--task", taskId!, "--phase", phaseId!)
		} else if (/^https?:\/\//.test(target)) {
			requireValue(key !== undefined, `No ticket key found in ${target}`)
			context = await contextOf(await byTicket(key))
		} else {
			// Exact task IDs win; ticket-shaped IDs fall back to ticket matching.
			try {
				context = await contextOf(target)
			} catch (error) {
				if (
					key === undefined ||
					(error as { code?: string }).code !== "CONTEXT_ERROR"
				)
					throw error
				context = await contextOf(await byTicket(key))
			}
		}
		const resolved = object(context.target)
		const kind = text(resolved.kind)
		const documentPath = text(resolved.path)
		const directory = dirname(documentPath)
		requireValue(
			resolved.archived !== true,
			`Target is archived: ${documentPath}`,
		)
		const taskId = kind === "epic" ? undefined : text(resolved.taskId)
		const label =
			kind === "epic"
				? text(resolved.epicId)
				: kind === "phase"
					? `${taskId}/${text(resolved.phaseId)}`
					: taskId!
		Object.assign(ids, { target: label, kind, documentPath })
		const mode = object(context.authority).mode
		const execution = mode === "execution" || mode === "review"
		const identity =
			kind === "epic"
				? `epic:${label}`
				: kind === "phase"
					? `execution-unit:phase/${label}`
					: execution
						? `execution-unit:task/${label}`
						: `task:${label}`
		if (env.AGENCY_TARGET)
			requireValue(
				env.AGENCY_TARGET !== identity,
				`An Agency worker cannot launch itself (${identity})`,
			)

		stage = "preflight"
		const graph = object(context.graph)
		const readiness = object(graph.readiness)
		requireValue(
			object(context.validation).valid === true,
			`Agency validation failed for ${label}`,
		)
		requireValue(readiness.terminal !== true, `${label} is already terminal`)
		const permission = options.allowWorkingDependencies
			? ["--allow-working-dependencies"]
			: []
		if (execution) {
			let preview: ObjectValue
			try {
				preview = object(
					await agencyCall(
						[
							"work",
							"prepare",
							directory,
							"--dry-run",
							"--json",
							...permission,
						],
						120_000,
					),
				)
			} catch (error) {
				const blocked =
					(error as { code?: string }).code === "EXECUTION_BLOCKED" &&
					!options.allowWorkingDependencies
				throw new Error(
					`${error instanceof Error ? error.message : String(error)}${blocked ? " (if the only blockers are working dependencies and the user authorized starting anyway, rerun with --allow-working-dependencies)" : ""}`,
				)
			}
			const validation = object(preview.validation)
			const issues = validation.issues
			requireValue(
				validation.valid === true &&
					(!Array.isArray(issues) || issues.length === 0),
				`Preparation validation failed: ${JSON.stringify(issues)}`,
			)
			const workspace =
				preview.workspace && typeof preview.workspace === "object"
					? (preview.workspace as ObjectValue)
					: {}
			const warnings = workspace.warnings
			requireValue(
				!Array.isArray(warnings) || warnings.length === 0,
				`Preparation reported workspace warnings: ${JSON.stringify(warnings)}`,
			)
		} else {
			requireValue(
				readiness.ready === true ||
					object(graph.aggregate ?? {}).status === "working",
				`${label} is not ready or resumable: ${JSON.stringify(readiness.blockers ?? [])}`,
			)
		}

		const work = [
			shellQuote(agency),
			"work",
			".",
			...(options.intent === "launch" ? ["--auto"] : []),
			...permission,
		].join(" ")
		const editor = `nvim -- ${shellQuote(basename(documentPath))}`
		const failureTitle = "Agency launch failed"
		const failureBody = `${label}: agency work exited with an error. See its tab.`

		if (mux === "rex") {
			stage = "tab-create"
			const session = text(ids.sessionId)
			// Rex blocks take no environment option, so wrap the login shell.
			const shellEnv =
				env.OPENCODE_CONFIG_CONTENT === undefined
					? {}
					: {
							shell: "none",
							command: [
								"/usr/bin/env",
								`OPENCODE_CONFIG_CONTENT=${env.OPENCODE_CONFIG_CONTENT}`,
								env.SHELL || "/bin/zsh",
								"-l",
							],
						}
			const block = (name: string, input: string) => ({
				block: {
					flavor: "com.superlogical.terminal.shell",
					label: name,
					options: { cwd: directory, ...shellEnv, initial_input: `${input}\n` },
				},
			})
			// OSC 777 asks Rex for a desktop notification.
			const notify = [
				"printf",
				shellQuote("\\033]777;notify;%s;%s\\033\\\\"),
				shellQuote(failureTitle),
				shellQuote(failureBody),
			].join(" ")
			const request = {
				window_label: label,
				focus: false,
				layout: {
					split: {
						direction: "horizontal",
						before: block("worker", `${work} || ${notify}`),
						after: block("editor", editor),
					},
				},
			}
			const argv = [
				"rex",
				"--autostart=false",
				"api",
				"call",
				"-s",
				session,
				"session.new_window",
				JSON.stringify(request),
			]
			const output = await io.run(argv, cwd, 15_000)
			requireValue(
				output.status === 0,
				`rex session.new_window failed: ${(output.stderr || output.stdout).trim()}`,
			)
			let created: ObjectValue
			try {
				created = object(JSON.parse(output.stdout.trim()))
			} catch {
				throw new Error(
					`Invalid JSON from rex session.new_window: ${output.stdout.trim()}`,
				)
			}
			const blocks = created.block_ids
			requireValue(
				Array.isArray(blocks) && blocks.length === 2,
				`Unexpected rex session.new_window result: ${output.stdout.trim()}`,
			)
			ids.tabId = text(created.window_id)
			ids.workerPaneId = text(blocks[0])
			ids.editorPaneId = text(blocks[1])
			io.emit({ event: "launched", intent: options.intent, ...ids })
			return 0
		}

		const herdr = async (argv: string[], type?: string) => {
			const output = await io.run(["herdr", ...argv], cwd, 15_000)
			const name = `herdr ${argv.slice(0, 2).join(" ")}`
			// Herdr's pane run command prints nothing on success.
			if (type === undefined) {
				requireValue(
					output.status === 0,
					`${name} failed: ${(output.stderr || output.stdout).trim()}`,
				)
				return {}
			}
			let envelope: ObjectValue
			try {
				envelope = object(
					JSON.parse(output.stdout.trim() || output.stderr.trim()),
				)
			} catch {
				throw new Error(
					`Invalid JSON from ${name}: ${(output.stderr || output.stdout).trim()}`,
				)
			}
			requireValue(
				output.status === 0 && envelope.error === undefined,
				`${name} failed: ${JSON.stringify(envelope.error ?? output)}`,
			)
			const result = object(envelope.result)
			requireValue(
				result.type === type,
				`Unexpected ${name} result: ${result.type}`,
			)
			return result
		}
		const paneEnv =
			env.OPENCODE_CONFIG_CONTENT === undefined
				? []
				: ["--env", `OPENCODE_CONFIG_CONTENT=${env.OPENCODE_CONFIG_CONTENT}`]

		stage = "tab-create"
		const created = await herdr(
			[
				"tab",
				"create",
				"--workspace",
				text(ids.workspaceId),
				"--cwd",
				directory,
				"--label",
				label,
				"--no-focus",
				...paneEnv,
			],
			"tab_created",
		)
		ids.tabId = text(object(created.tab).tab_id)
		const workerId = text(object(created.root_pane).pane_id)
		ids.workerPaneId = workerId

		stage = "editor-split"
		const split = await herdr(
			[
				"pane",
				"split",
				"--pane",
				workerId,
				"--direction",
				"right",
				"--cwd",
				directory,
				"--no-focus",
				...paneEnv,
			],
			"pane_info",
		)
		const editorId = text(object(split.pane).pane_id)
		ids.editorPaneId = editorId

		stage = "worker-run"
		const notify = [
			"herdr",
			"notification",
			"show",
			shellQuote(failureTitle),
			"--body",
			shellQuote(failureBody),
			"--sound",
			"request",
		].join(" ")
		await herdr(["pane", "run", workerId, `${work} || ${notify}`])

		stage = "editor-run"
		await herdr(["pane", "run", editorId, editor])

		io.emit({ event: "launched", intent: options.intent, ...ids })
		return 0
	} catch (error) {
		io.emit({
			event: "error",
			stage,
			...ids,
			message: error instanceof Error ? error.message : String(error),
			...(ids.tabId
				? { recovery: "The tab was created and left visible for recovery." }
				: {}),
		})
		return 1
	}
}
