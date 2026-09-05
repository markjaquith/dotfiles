import { spawnSync } from "node:child_process"
import { createHash } from "node:crypto"
import { accessSync, constants, statSync, writeSync } from "node:fs"
import { basename, isAbsolute, resolve } from "node:path"
import {
	parse as parseJsonc,
	printParseErrorCode,
	type ParseError,
} from "jsonc-parser"
import type { Runtime as SetupRuntime } from "./agency-herdr-setup.ts"

type ObjectValue = Record<string, unknown>
export type Runtime = Pick<SetupRuntime, "run" | "emit"> & {
	checkExecutable: (path: string) => void
}
export const setupProfile = "agency-herdr-dispatch-setup"
export const setupModel = "openai/gpt-5.6-sol"

// Tab env reaches worker panes too. Select this profile only via setup's --agent.
export const setupConfig = {
	$schema: "https://opencode.ai/config.json",
	agent: {
		[setupProfile]: {
			mode: "primary",
			model: setupModel,
			variant: "low",
			options: { reasoningEffort: "low" },
		},
	},
}

const runtime: Runtime = {
	checkExecutable(path) {
		requireValue(statSync(path).isFile(), "Not a regular file")
		accessSync(path, constants.X_OK)
	},
	async run(argv, cwd, timeout) {
		const result = spawnSync(argv[0]!, argv.slice(1), {
			cwd,
			encoding: "utf8",
			stdio: ["ignore", "pipe", "pipe"],
			timeout,
			killSignal: "SIGKILL",
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
			value.trim().length > 0 &&
			!/[\x00-\x1f\x7f]/.test(value),
		"Expected nonempty text without control characters",
	)
	return value
}

function shellQuote(value: string): string {
	return `'${value.replaceAll("'", "'\\''")}'`
}

export async function main(
	args: string[],
	io: Runtime = runtime,
	env: NodeJS.ProcessEnv = process.env,
	processCwd = process.cwd(),
): Promise<number> {
	const ids: ObjectValue = {}
	let stage = "preflight"
	let allocationAttempted = false
	try {
		const options = new Map<string, string>()
		let allowWorkingDependencies = false
		for (let i = 0; i < args.length; i++) {
			const key = args[i]!
			requireValue(!options.has(key), `Duplicate option: ${key}`)
			if (key === "--allow-working-dependencies") {
				allowWorkingDependencies = true
				options.set(key, "true")
				continue
			}
			requireValue(
				[
					"--intent",
					"--request",
					"--cwd",
					"--label",
					"--agency-executable",
				].includes(key),
				`Unknown option: ${key}`,
			)
			const value = args[++i]
			requireValue(
				value !== undefined && !value.includes("\0"),
				`Missing or invalid value for ${key}`,
			)
			options.set(key, value)
		}
		const intent = options.get("--intent")
		requireValue(
			intent === "open" || intent === "launch",
			"Explicit --intent open|launch is required",
		)
		const request = options.get("--request")
		requireValue(
			request !== undefined && request.trim().length > 0,
			"Complete --request is required",
		)
		const cwd = resolve(processCwd, text(options.get("--cwd") ?? processCwd))
		const label = text(options.get("--label") ?? (basename(cwd) || "agency"))
		requireValue(env.HERDR_ENV === "1", "HERDR_ENV=1 is required")
		requireValue(
			env.AGENCY_SESSION_ID === undefined && env.AGENCY_TARGET === undefined,
			"Active Agency workers cannot dispatch nested setup agents (even an empty defined session variable blocks dispatch)",
		)
		const workspaceId = text(env.HERDR_WORKSPACE_ID)
		const originTabId = text(env.HERDR_TAB_ID)
		const originPaneId = text(env.HERDR_PANE_ID)
		Object.assign(ids, { workspaceId, originTabId, originPaneId })
		// Match OpenCode's JSONC syntax, but never accept the parser's partial result.
		const parseErrors: ParseError[] = []
		const parsed: unknown = parseJsonc(
			env.OPENCODE_CONFIG_CONTENT || "{}",
			parseErrors,
			{ allowTrailingComma: true },
		)
		requireValue(
			parseErrors.length === 0,
			`Invalid OPENCODE_CONFIG_CONTENT: ${parseErrors.map((error) => `${printParseErrorCode(error.error)} at offset ${error.offset}`).join(", ")}`,
		)
		const inherited = object(parsed)
		const executable = options.get("--agency-executable")
		if (executable !== undefined) {
			try {
				text(executable)
				requireValue(
					isAbsolute(executable) && resolve(executable) === executable,
					"Expected normalized absolute executable path",
				)
				io.checkExecutable(executable)
			} catch (error) {
				throw new Error(
					`Invalid --agency-executable ${JSON.stringify(executable)}: ${error instanceof Error ? error.message : String(error)}`,
				)
			}
		}
		const agencyCommand =
			executable === undefined ? "agency" : shellQuote(executable)
		const executableOption =
			executable === undefined ? "" : ` --agency-executable ${agencyCommand}`

		// Preserve inherited inline configuration, including permissions and providers.
		const config = JSON.stringify({
			...inherited,
			...setupConfig,
			agent: {
				...(inherited.agent === undefined ? {} : object(inherited.agent)),
				...setupConfig.agent,
			},
		})
		const call = async (argv: string[], type: string, timeout = 15_000) => {
			const output = await io.run(["herdr", ...argv], cwd, timeout)
			let envelope: ObjectValue
			try {
				envelope = object(
					JSON.parse(output.stdout.trim() || output.stderr.trim()),
				)
			} catch {
				throw new Error(
					`Invalid JSON from herdr ${argv.slice(0, 2).join(" ")}: ${JSON.stringify(output)}`,
				)
			}
			requireValue(
				output.status === 0 && !("error" in envelope) && envelope.ok !== false,
				`herdr ${argv.slice(0, 2).join(" ")} failed: ${JSON.stringify(output)}`,
			)
			requireValue(
				envelope.id === `cli:${argv[0]}:${argv[1]}`,
				"Unexpected Herdr response ID",
			)
			const result = object(envelope.result)
			// Retain returned handles even if the rest of an allocation response is invalid.
			if (stage === "tab-create") {
				const tab = result.tab as ObjectValue | undefined
				const pane = result.root_pane as ObjectValue | undefined
				if (typeof tab?.tab_id === "string") ids.tabId = tab.tab_id
				if (typeof pane?.pane_id === "string") ids.setupId = pane.pane_id
			}
			requireValue(
				result.type === type,
				`Unexpected Herdr result type: ${result.type}`,
			)
			return result
		}
		const pane = (value: unknown, tabId: string, paneId: string) => {
			const info = object(value)
			requireValue(
				info.workspace_id === workspaceId &&
					info.tab_id === tabId &&
					info.pane_id === paneId,
				"Unexpected pane identity or location",
			)
			return info
		}
		stage = "caller-verify"
		pane(
			(await call(["pane", "get", originPaneId], "pane_info")).pane,
			originTabId,
			originPaneId,
		)
		stage = "tab-create"
		allocationAttempted = true
		const created = await call(
			[
				"tab",
				"create",
				"--workspace",
				workspaceId,
				"--cwd",
				cwd,
				"--label",
				label,
				"--no-focus",
				"--env",
				`OPENCODE_CONFIG_CONTENT=${config}`,
				"--env",
				`AGENCY_HERDR_ORIGIN_PANE_ID=${originPaneId}`,
				"--env",
				`AGENCY_HERDR_ORIGIN_TAB_ID=${originTabId}`,
				"--env",
				`AGENCY_HERDR_ORIGIN_WORKSPACE_ID=${workspaceId}`,
			],
			"tab_created",
		)
		const tab = object(created.tab)
		const tabId = text(tab.tab_id)
		const setupId = text(object(created.root_pane).pane_id)
		requireValue(
			tab.workspace_id === workspaceId &&
				tabId !== originTabId &&
				setupId !== originPaneId,
			"Tab creation reused caller IDs or changed workspace",
		)
		pane(created.root_pane, tabId, setupId)
		const name = `agency-setup-${createHash("sha256").update(setupId).digest("hex").slice(0, 16)}`
		ids.agentName = name
		io.emit({ event: "allocated", ...ids, cwd, intent })
		stage = "agent-start"
		// --model would activate mini's saved variant instead of the profile's low.
		const nativeArgs = ["--mini", "--agent", setupProfile]
		const started = await call(
			[
				"agent",
				"start",
				name,
				"--kind",
				"opencode",
				"--pane",
				setupId,
				"--timeout",
				"30000",
				"--",
				...nativeArgs,
			],
			"agent_started",
			35_000,
		)
		const agent = pane(started.agent, tabId, setupId)
		requireValue(
			agent.name === name &&
				agent.agent === "opencode" &&
				agent.interactive_ready === true,
			"Setup agent is not the expected ready OpenCode agent",
		)
		requireValue(
			JSON.stringify(started.argv) ===
				JSON.stringify(["opencode", ...nativeArgs]),
			"Unexpected setup agent argv",
		)
		const failureBody = `Origin ${originPaneId} (${originTabId}, ${workspaceId}); setup ${setupId} (${tabId}, ${workspaceId}). Initial resolution or creation failed before the helper started. See setup diagnostics; do not rerun blindly.`
		const failureNotice = `herdr notification show "Agency setup failed" --body "${failureBody.replace(/[\\"$`]/g, "\\$&")}" --sound request`
		const prompt = `You are the temporary Agency setup agent, not the implementation worker.
Intended Agency action: ${intent}.
Original request cwd (use this as the cwd of Agency commands): ${JSON.stringify(cwd)}.
The initiating agent has already created this unfocused setup tab and explicitly selected your setup-only model/profile with low reasoning effort. Preserve inherited implementation-worker defaults; do not set default_agent, global model/provider overrides, or change worker configuration to match this temporary profile. Do not dispatch another setup agent.
Use ${agencyCommand} for ALL Agency commands in this run, including lookups, creation, help, and any authorized metadata updates. Do not change PATH, replace the global agency command, install a CLI, or fall back to another executable on failure. The helper receives the same selection below. Paths and replacement values are data: use separate argv entries or shell-quote each value, never evaluate request text as shell. Single-quoted angle-bracket values below are placeholders to replace with actual quoted values. The complete original user request remains authoritative for the requested work; do not summarize away its requirements.

This is a prescribed fast path. Interpret the complete user request below, then:
1. If creation was requested, create the durable item directly with the appropriate noninteractive Agency mutation and --json. Do not add --work or --auto to creation. Explicit new/separate/follow-up work means a distinct item, not reuse of the investigation. Otherwise resolve the existing requested item. Capture its exact absolute document path from successful Agency JSON output. On creation failure, follow the pre-helper failure procedure below and stop; do not retry blindly.
2. Use only necessary, narrow context lookups. For a named phase whose branch or path is missing, run ${agencyCommand} phase show '<task-id>' '<phase-id>' --json; read result.path and result.data.branch. Then ${agencyCommand} context '<absolute-document-path>' --json supplies authoritative context. For a supplied document path, use ${agencyCommand} context '<document-path>' --json directly. For current-item context use ${agencyCommand} context . --json from the original cwd. Never infer a phase branch from its slug. Do not use broad globs, graph searches, example tasks, source inspection, or tool/subagent discovery. If syntax is genuinely missing, inspect only the narrow relevant command help with ${agencyCommand}. If identity remains ambiguous, report the missing detail and follow the pre-helper failure procedure below.
3. Creation recipes: ${agencyCommand} task create '<id>' --repo '<alias>' --branch '<branch>' --base '<base>' --description '<text>' --json; ${agencyCommand} phase create '<task-id>' '<phase-id>' --repo '<alias>' --branch '<branch>' --base '<base>' --description '<text>' --json; ${agencyCommand} epic create '<id>' --description '<text>' --json. Supply only user-authorized metadata and required resolved values; use narrow help for container/handoff variants. Preserve the full requirements in the durable item, not just its title.
4. Branch ancestry is NOT a completion gate. Never automatically add --depends-on merely because --base is another phase's branch. Preserve explicit user gate declarations. Existing dependencies remain unless the user explicitly asks to remove them. Never mark a dependency done to bypass readiness.
5. Invoke agency-herdr-setup '<absolute-document-path>' --intent ${intent}${allowWorkingDependencies ? " --allow-working-dependencies" : ""}${executableOption} exactly once, quoting the path, in this setup pane with its inherited Herdr environment. Do not override HERDR_WORKSPACE_ID, HERDR_TAB_ID, or HERDR_PANE_ID.
For every Bash tool call invoking the helper, explicitly set the tool's timeout field to 1200000 milliseconds (20 minutes), not the default 120000. This is the caller budget for the entire transaction, including recovery, final verification, notification, and cleanup, not a helper CLI flag or a delay. Run creation, lookups, and user-authorized metadata modifications in separate calls with their own budgets; do not consume the helper's caller budget with earlier work. The helper defaults to 300000ms for applying preparation, 120000ms each for context and dry-run, and 60000ms for startup detection. If explicitly adjusting --prepare-timeout-ms or --timeout-ms, increase the caller timeout to at least 1200000 + max(0, prepareTimeoutMs - 300000) + max(0, startupTimeoutMs - 60000). Shell clients run the helper plainly without a shorter timeout wrapper. Do not add sleeps, poll for the budget duration, or retry the helper on timeout.
${allowWorkingDependencies ? "The dispatcher received the explicit --allow-working-dependencies opt-in. Pass it to the helper ONLY if the original user request explicitly asks to start now despite existing working dependencies; otherwise stop and report the authorization mismatch. Before launch, record that invocation-specific approval in the durable item's Important Decisions: the preserved working dependency is expected for this authorized run, so the worker should proceed without asking again about that same gate; other safety checks and future invocations are not waived." : "No working-dependency override was authorized by the dispatcher. Do not add --allow-working-dependencies. If the user needs that exception, report the blocker for an explicitly opted-in dispatch."}
Never use --force. If the helper does not support the dedicated flag, stop; do not fall back to --force or remove dependencies.
6. Before the helper starts, if initial resolution or creation fails (or the helper cannot be invoked), report diagnostics in this setup pane, run exactly this native toast command once, then stop and leave the pane visible:
${failureNotice}
Do not retry a failed toast. Never focus the origin or inject text, keys, or prompts into it. The origin is AGENCY_HERDR_ORIGIN_PANE_ID=${originPaneId}, AGENCY_HERDR_ORIGIN_TAB_ID=${originTabId}, AGENCY_HERDR_ORIGIN_WORKSPACE_ID=${workspaceId}; these are notification metadata, NOT caller-ID replacements or an input destination.
7. Once the helper starts, it owns the once-only failure toast. Do not send another notification after a helper error, including cleanup errors. The helper owns context inspection, tab naming, execution-only preparation, worker-left/editor-right layout, launch, bounded startup detection, final verification, and closing this setup pane on success. Do not duplicate its mechanics, append verification, poll work completion, or focus anything.
Success includes closing the temporary setup pane, not merely spawning a worker and leaving this agent idle. Let the helper close it. Only if the helper returns exit status 0 to this still-open setup pane, close this pane once with herdr pane close ${shellQuote(setupId)}. A complete event alone is not success: pane cleanup follows it. On any helper or pane-cleanup failure, including a cleanup error after worker launch, leave recovery panes visible and report the exact error and emitted IDs. Never call the helper again or close the pane automatically after failure; recovery requires explicit human authorization.

Complete original user request follows verbatim (all remaining text):
${request}`
		stage = "prompt"
		const accepted = await call(
			["agent", "prompt", name, prompt],
			"agent_prompted",
		)
		const prompted = pane(accepted.agent, tabId, setupId)
		requireValue(
			prompted.name === name && prompted.agent === "opencode",
			"Prompt accepted by an unexpected agent",
		)
		io.emit({
			event: "accepted",
			...ids,
			cwd,
			intent,
			message: "Setup prompt accepted; not waiting for work completion",
		})
		return 0
	} catch (error) {
		io.emit({
			event: "error",
			stage,
			...ids,
			message: error instanceof Error ? error.message : String(error),
			recovery: allocationAttempted
				? "Leave allocated tabs/panes visible. Allocation or prompt acceptance may have occurred even on timeout; do not automatically retry. Use returned IDs for recovery."
				: "No tab allocation attempted.",
		})
		return 1
	}
}
