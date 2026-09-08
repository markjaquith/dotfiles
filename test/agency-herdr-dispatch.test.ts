import { describe, expect, test } from "bun:test"
import { accessSync, constants } from "node:fs"
import { resolve } from "node:path"
import {
	main,
	setupConfig,
	setupProfile,
	workerConfigEnv,
	type Runtime,
} from "../bin/agency-herdr-dispatch.ts"

type ObjectValue = Record<string, unknown>
type Output = Awaited<ReturnType<Runtime["run"]>>
const cwd = "/workbase/tasks/example-task"
const env = {
	HERDR_ENV: "1",
	HERDR_WORKSPACE_ID: "w3S",
	HERDR_TAB_ID: "w3S:t20",
	HERDR_PANE_ID: "w3S:p47",
}

// Full wire shapes from read-only pane/agent get and a prior CLI transcript.
// The historical tab/start/prompt responses use these actual opaque handles.
// Caller identity, private paths/labels, and dynamic agent names are substituted.
const rootPane = {
	agent_status: "unknown",
	cwd,
	focused: false,
	foreground_cwd: cwd,
	pane_id: "w3S:p48",
	revision: 0,
	scroll: {
		max_offset_from_bottom: 0,
		offset_from_bottom: 0,
		viewport_rows: 59,
	},
	tab_id: "w3S:t21",
	terminal_id: "term_65abea6a0f49116",
	workspace_id: "w3S",
}
const caller = {
	id: "cli:pane:get",
	result: {
		pane: {
			agent: "opencode",
			agent_status: "blocked",
			cwd,
			focused: true,
			foreground_cwd: cwd,
			pane_id: env.HERDR_PANE_ID,
			revision: 5,
			scroll: {
				max_offset_from_bottom: 0,
				offset_from_bottom: 0,
				viewport_rows: 59,
			},
			tab_id: env.HERDR_TAB_ID,
			terminal_id: "term_65ab567eb0e2c13",
			terminal_title: "OC | Improving dotfiles",
			terminal_title_stripped: "OC | Improving dotfiles",
			workspace_id: env.HERDR_WORKSPACE_ID,
		},
		type: "pane_info",
	},
}
const created = {
	id: "cli:tab:create",
	result: {
		root_pane: rootPane,
		tab: {
			agent_status: "unknown",
			focused: false,
			label: "Example round 5 setup",
			number: 65,
			pane_count: 1,
			tab_id: "w3S:t21",
			workspace_id: "w3S",
		},
		type: "tab_created",
	},
}
const agent = {
	agent: "opencode",
	agent_status: "idle",
	cwd,
	focused: false,
	foreground_cwd: cwd,
	interactive_ready: true,
	name: "round5_setup",
	pane_id: "w3S:p48",
	revision: 0,
	state_change_seq: 32,
	tab_id: "w3S:t21",
	terminal_id: "term_65abea6a0f49116",
	workspace_id: "w3S",
}
const output = (value: unknown): Output => ({
	status: 0,
	stdout: JSON.stringify(value),
	stderr: "",
})
const failure: Output = {
	status: 1,
	stdout: "",
	stderr: JSON.stringify({
		id: "cli:agent:start",
		error: { code: "agent_start_timeout", message: "Startup timed out" },
	}),
}

function fake(
	overrides: Record<number, Output | Error | ((argv: string[]) => Output)> = {},
) {
	const calls: { argv: string[]; cwd: string; timeout: number }[] = []
	const events: ObjectValue[] = []
	const checkedExecutables: string[] = []
	let name = ""
	const io: Runtime = {
		checkExecutable(path) {
			expect(calls).toHaveLength(0)
			checkedExecutables.push(path)
		},
		emit: (event) => {
			events.push(event)
		},
		async run(argv, cwd, timeout) {
			calls.push({ argv, cwd, timeout })
			const override = overrides[calls.length]
			if (override instanceof Error) throw override
			if (typeof override === "function") return override(argv)
			if (override) return override
			if (calls.length === 1) return output(caller)
			if (calls.length === 2) return output(created)
			if (calls.length === 3) {
				name = argv[3]!
				return output({
					id: "cli:agent:start",
					result: {
						agent: { ...agent, name },
						argv: ["opencode"],
						type: "agent_started",
					},
				})
			}
			if (calls.length === 4)
				return output({
					id: "cli:agent:prompt",
					result: { agent: { ...agent, name }, type: "agent_prompted" },
				})
			throw new Error(`Unexpected extra command: ${argv.join(" ")}`)
		},
	}
	return { io, calls, events, checkedExecutables }
}

const args = [
	"--intent",
	"launch",
	"--request",
	"Create and launch the next phase",
]

const inheritedJsonc = String.raw`// Inherited worker settings, not setup defaults.
{
  "default_agent": "implementation",
  "model": "openai/gpt-6-astra",
  "provider": {
    "openai": { "options": { "baseURL": "https://example.invalid//api", }, },
  },
  /* Retain the worker profile and literal comment markers inside strings. */
  "agent": {
    "implementation": {
      "mode": "primary",
      "options": { "reasoningEffort": "high", },
    },
  },
  "instructions": ["Keep // and /* markers */ literal.", "Quote: \"ok\"",],
} // trailing comment
`

describe("agency-herdr-dispatch", () => {
	test("preserves inherited JSONC settings with comments and trailing commas", async () => {
		const f = fake()
		expect(
			await main(
				args,
				f.io,
				{ ...env, OPENCODE_CONFIG_CONTENT: inheritedJsonc },
				cwd,
			),
		).toBe(0)
		const assignment = f.calls[1]!.argv.find((arg) =>
			arg.startsWith("OPENCODE_CONFIG_CONTENT="),
		)!
		const config = JSON.parse(
			assignment.slice("OPENCODE_CONFIG_CONTENT=".length),
		)
		expect(config).toEqual({
			$schema: "https://opencode.ai/config.json",
			default_agent: setupProfile,
			model: "openai/gpt-6-astra",
			provider: {
				openai: { options: { baseURL: "https://example.invalid//api" } },
			},
			agent: {
				implementation: {
					mode: "primary",
					options: { reasoningEffort: "high" },
				},
				[setupProfile]: {
					mode: "primary",
					model: "openai/gpt-5.6-sol",
					variant: "low",
					options: { reasoningEffort: "low" },
				},
			},
			instructions: ["Keep // and /* markers */ literal.", 'Quote: "ok"'],
		})
	})

	test.each([
		'{"default_agent":"implementation", broken}',
		'{"model":"openai/gpt-6-astra" "default_agent":"implementation"}',
		'{"default_agent":"unterminated}',
		'{"model":"openai/gpt-6-astra"} /* unterminated',
		"{} trailing-content",
		'{"default_agent":undefined}',
	])(
		"rejects malformed JSONC instead of using a partial result before any tools: %j",
		async (content) => {
			const f = fake()
			expect(
				await main(
					[...args, "--agency-executable", "/managed/agency"],
					f.io,
					{ ...env, OPENCODE_CONFIG_CONTENT: content },
					cwd,
				),
			).toBe(1)
			expect(f.calls).toHaveLength(0)
			expect(f.checkedExecutables).toEqual([])
			expect(f.events.at(-1)!.message).toContain(
				"Invalid OPENCODE_CONFIG_CONTENT",
			)
		},
	)
	test("entrypoint is executable without launching it", () => {
		expect(() =>
			accessSync(
				new URL("../bin/agency-herdr-dispatch", import.meta.url),
				constants.X_OK,
			),
		).not.toThrow()
	})
	test.each(["open", "launch"])(
		"%s orders exactly four calls and returns on prompt acceptance",
		async (intent) => {
			const f = fake()
			expect(
				await main(
					["--intent", intent, "--request", "complete request"],
					f.io,
					env,
					cwd,
				),
			).toBe(0)
			expect(f.calls.map(({ argv }) => argv.slice(0, 3))).toEqual([
				["herdr", "pane", "get"],
				["herdr", "tab", "create"],
				["herdr", "agent", "start"],
				["herdr", "agent", "prompt"],
			])
			expect(f.calls[0]!.argv).toEqual(["herdr", "pane", "get", "w3S:p47"])
			const tab = f.calls[1]!.argv
			expect(tab.slice(0, 10)).toEqual([
				"herdr",
				"tab",
				"create",
				"--workspace",
				"w3S",
				"--cwd",
				cwd,
				"--label",
				"example-task",
				"--no-focus",
			])
			const name = f.calls[2]!.argv[3]!
			expect(name).toMatch(/^[a-z][a-z0-9_-]{0,31}$/)
			expect(f.calls[2]!.argv).toEqual([
				"herdr",
				"agent",
				"start",
				name,
				"--kind",
				"opencode",
				"--pane",
				"w3S:p48",
				"--timeout",
				"30000",
			])
			expect(f.calls[3]!.argv.slice(0, 4)).toEqual([
				"herdr",
				"agent",
				"prompt",
				name,
			])
			expect(f.calls[3]!.argv).toHaveLength(5)
			expect(f.calls.map(({ timeout }) => timeout)).toEqual([
				15000, 15000, 35000, 15000,
			])
			expect(f.calls.every((call) => call.cwd === cwd)).toBe(true)
			expect(f.events.at(-1)).toMatchObject({
				event: "accepted",
				intent,
				workspaceId: "w3S",
				tabId: "w3S:t21",
				setupId: "w3S:p48",
				agentName: name,
			})
			const prompt = f.calls[3]!.argv[4]!
			expect(f.checkedExecutables).toEqual([])
			expect(prompt).toContain(
				`agency-herdr-setup '<absolute-document-path>' --intent ${intent} exactly once`,
			)
			expect(prompt).toContain(
				"agency phase show '<task-id>' '<phase-id>' --json",
			)
			expect(prompt).toContain("result.path and result.data.branch")
			expect(prompt).toContain(
				"agency context '<absolute-document-path>' --json",
			)
			expect(prompt).toContain("Branch ancestry is NOT a completion gate")
			expect(prompt).toContain(
				"Existing dependencies remain unless the user explicitly asks to remove them",
			)
			expect(prompt).toContain("Never use --force")
			expect(prompt).toContain("Do not add --allow-working-dependencies")
			expect(prompt).not.toContain("--agency-executable")
		},
	)

	test("preserves every request byte and passes cwd/label as argv, not shell", async () => {
		const f = fake()
		const request =
			"  Launch 'phase'\r\n$(touch /tmp/not-executed); `false`\nUnicode: \u2603\t\n"
		const path = "/work base/owner's project; $(false)"
		const label = "Setup 'phase'; $(false)"
		expect(
			await main(
				[
					"--intent",
					"open",
					"--request",
					request,
					"--cwd",
					path,
					"--label",
					label,
				],
				f.io,
				env,
				cwd,
			),
		).toBe(0)
		const prompt = f.calls[3]!.argv[4]!
		const marker =
			"Complete original user request follows verbatim (all remaining text):\n"
		expect(
			Buffer.from(prompt.slice(prompt.indexOf(marker) + marker.length)),
		).toEqual(Buffer.from(request))
		expect(prompt).toContain(JSON.stringify(path))
		expect(f.calls.every((call) => call.cwd === path)).toBe(true)
		expect(f.calls[1]!.argv[8]).toBe(label)
	})

	test.each(["open", "launch"])(
		"%s validates and quotes an explicit executable in all Agency recipes and helper handoff",
		async (intent) => {
			const f = fake()
			const executable = "/managed/owner's $(false) `false` CLI/agency"
			const quoted = "'/managed/owner'\\''s $(false) `false` CLI/agency'"
			const request =
				"  Use agency phase show 'original'; start now despite existing working dependencies\n"
			expect(
				await main(
					[
						"--intent",
						intent,
						"--agency-executable",
						executable,
						"--allow-working-dependencies",
						"--request",
						request,
					],
					f.io,
					env,
					cwd,
				),
			).toBe(0)
			expect(f.checkedExecutables).toEqual([executable])
			expect(f.calls).toHaveLength(4)
			expect(f.calls.every(({ argv }) => argv[0] === "herdr")).toBe(true)
			const prompt = f.calls[3]!.argv[4]!
			const protocol = prompt.split(
				"Complete original user request follows verbatim (all remaining text):\n",
			)[0]!
			for (const command of [
				"phase show '<task-id>' '<phase-id>' --json",
				"context '<absolute-document-path>' --json",
				"context '<document-path>' --json",
				"context . --json",
				"task create '<id>'",
				"phase create '<task-id>' '<phase-id>'",
				"epic create '<id>'",
			]) {
				expect(protocol).toContain(`${quoted} ${command}`)
			}
			expect(protocol).toContain(`command help with ${quoted}`)
			expect(protocol).toContain(
				`agency-herdr-setup '<absolute-document-path>' --intent ${intent} --allow-working-dependencies --agency-executable ${quoted} exactly once`,
			)
			expect(protocol).not.toMatch(/\bagency (?:context|phase|task|epic) /)
			expect(protocol).toContain(
				"Existing dependencies remain unless the user explicitly asks to remove them",
			)
			expect(protocol).toContain(
				"Do not change PATH, replace the global agency command",
			)
			expect(prompt.endsWith(request)).toBe(true)
			const assignment = f.calls[1]!.argv.find((arg) =>
				arg.startsWith("OPENCODE_CONFIG_CONTENT="),
			)!
			expect(
				JSON.parse(assignment.slice("OPENCODE_CONFIG_CONTENT=".length)),
			).toEqual(setupConfig)
		},
	)

	test.each([
		"relative/agency",
		"/tmp/../agency",
		"/tmp/agency/",
		"",
		"/tmp/agency\n",
	])(
		"rejects a non-normalized absolute executable before any IO: %j",
		async (executable) => {
			const f = fake()
			expect(
				await main(
					[...args, "--agency-executable", executable],
					f.io,
					env,
					cwd,
				),
			).toBe(1)
			expect(f.checkedExecutables).toEqual([])
			expect(f.calls).toHaveLength(0)
			expect(f.events.at(-1)!.message).toContain("Invalid --agency-executable")
		},
	)

	test.each(["ENOENT", "Not a regular file", "EACCES"])(
		"fails executable validation before caller inspection or tab allocation: %s",
		async (message) => {
			const f = fake()
			f.io.checkExecutable = () => {
				throw new Error(message)
			}
			expect(
				await main(
					[...args, "--agency-executable", "/managed/agency"],
					f.io,
					env,
					cwd,
				),
			).toBe(1)
			expect(f.calls).toHaveLength(0)
			expect(f.events.at(-1)!.message).toContain(message)
			expect(f.events.at(-1)!.recovery).toBe("No tab allocation attempted.")
		},
	)

	test("prescribes one native pre-helper toast and success-only cleanup, never origin input", async () => {
		const f = fake()
		expect(await main(args, f.io, env, cwd)).toBe(0)
		const protocol = f.calls[3]!.argv[4]!
		expect(protocol.match(/herdr notification show/g)).toHaveLength(1)
		expect(protocol).toContain(
			'herdr notification show "Agency setup failed" --body "Origin w3S:p47 (w3S:t20, w3S); setup w3S:p48 (w3S:t21, w3S). Initial resolution or creation failed before the helper started. See setup diagnostics; do not rerun blindly." --sound request',
		)
		expect(protocol).toContain("Do not retry a failed toast")
		expect(protocol).toContain(
			"Never focus the origin or inject text, keys, or prompts into it",
		)
		expect(protocol).toContain(
			"Do not send another notification after a helper error, including cleanup errors",
		)
		expect(protocol).toContain(
			"Only if the helper returns exit status 0 to this still-open setup pane, close this pane once with herdr pane close 'w3S:p48'",
		)
		expect(protocol).toContain("A complete event alone is not success")
		expect(protocol).toContain(
			"Never call the helper again or close the pane automatically after failure; recovery requires explicit human authorization",
		)
		expect(f.calls).toHaveLength(4)
	})

	test.each(["open", "launch"])(
		"%s prescribes a full-transaction caller budget even with modified helper options",
		async (intent) => {
			const f = fake()
			expect(
				await main(
					[
						"--intent",
						intent,
						"--request",
						"Use --prepare-timeout-ms 600000 and --timeout-ms 300000",
					],
					f.io,
					env,
					cwd,
				),
			).toBe(0)
			const protocol = f.calls[3]!.argv[4]!.split(
				"Complete original user request follows verbatim",
			)[0]!
			expect(protocol).toContain(
				"For every Bash tool call invoking the helper, explicitly set the tool's timeout field to 1200000 milliseconds (20 minutes), not the default 120000",
			)
			expect(protocol).toContain(
				"including recovery, final verification, notification, and cleanup",
			)
			expect(protocol).toContain(
				"Run creation, lookups, and user-authorized metadata modifications in separate calls with their own budgets",
			)
			expect(protocol).toContain(
				"1200000 + max(0, prepareTimeoutMs - 300000) + max(0, startupTimeoutMs - 60000)",
			)
			expect(protocol).toContain(
				"Shell clients run the helper plainly without a shorter timeout wrapper",
			)
			expect(protocol).toContain(
				"Do not add sleeps, poll for the budget duration, or retry the helper on timeout",
			)
			expect(f.calls.map(({ timeout }) => timeout)).toEqual([
				15_000, 15_000, 35_000, 15_000,
			])
		},
	)

	test("quotes opaque origin IDs safely in the prescribed toast", async () => {
		const origin = 'w3S:p$variable`false`"\\opaque'
		const f = fake({
			1: output({
				...caller,
				result: {
					...caller.result,
					pane: { ...caller.result.pane, pane_id: origin },
				},
			}),
		})
		expect(await main(args, f.io, { ...env, HERDR_PANE_ID: origin }, cwd)).toBe(
			0,
		)
		expect(f.calls[3]!.argv[4]).toContain(
			'--body "Origin w3S:p\\$variable\\`false\\`\\"\\\\opaque (w3S:t20, w3S); setup w3S:p48',
		)
	})

	test("resolves relative cwd against process cwd, not PWD or UI focus", async () => {
		const f = fake()
		expect(
			await main(
				[...args, "--cwd", "../other"],
				f.io,
				{ ...env, PWD: "/wrong" },
				cwd,
			),
		).toBe(0)
		expect(f.calls[1]!.cwd).toBe(resolve(cwd, "../other"))
		expect(f.calls[1]!.argv[8]).toBe("other")
	})

	test.each([undefined, "/managed/agency"])(
		"preserves worker defaults and low setup config with executable %j",
		async (executable) => {
			const f = fake()
			const inherited = {
				default_agent: "implementation",
				model: "openai/gpt-6-astra",
				permission: { bash: "ask" },
				agent: {
					implementation: {
						mode: "primary",
						model: "openai/gpt-6-astra",
						options: { reasoningEffort: "high" },
					},
				},
				provider: { openai: { options: { timeout: 1234 } } },
			}
			const sourceEnv = {
				...env,
				AGENCY_HERDR_ORIGIN_PANE_ID: "stale",
				AGENCY_HERDR_ORIGIN_TAB_ID: "stale",
				AGENCY_HERDR_ORIGIN_WORKSPACE_ID: "stale",
				OPENCODE_CONFIG_CONTENT: JSON.stringify(inherited),
			}
			const before = { ...sourceEnv }
			expect(
				await main(
					[...args, ...(executable ? ["--agency-executable", executable] : [])],
					f.io,
					sourceEnv,
					cwd,
				),
			).toBe(0)
			expect(sourceEnv).toEqual(before)
			const tab = f.calls[1]!.argv
			const assignments = tab.flatMap((arg, i) =>
				arg === "--env" ? [tab[i + 1]!] : [],
			)
			expect(assignments).toEqual([
				`OPENCODE_CONFIG_CONTENT=${JSON.stringify({ ...inherited, ...setupConfig, agent: { ...inherited.agent, ...setupConfig.agent } })}`,
				`${workerConfigEnv}=${JSON.stringify(inherited)}`,
				"AGENCY_HERDR_ORIGIN_PANE_ID=w3S:p47",
				"AGENCY_HERDR_ORIGIN_TAB_ID=w3S:t20",
				"AGENCY_HERDR_ORIGIN_WORKSPACE_ID=w3S",
			])
			const config = JSON.parse(
				assignments[0]!.slice("OPENCODE_CONFIG_CONTENT=".length),
			)
			expect(config.default_agent).toBe(setupProfile)
			expect(config.agent[config.default_agent]).toEqual(
				config.agent[setupProfile],
			)
			expect(config.model).toBe(inherited.model)
			expect(config.provider).toEqual(inherited.provider)
			expect(config.agent[setupProfile]).toEqual({
				mode: "primary",
				model: "openai/gpt-5.6-sol",
				variant: "low",
				options: { reasoningEffort: "low" },
			})
			expect(
				f.calls.filter((call) => call.argv.includes("--env")),
			).toHaveLength(1)
		},
	)

	test("uses the setup profile only as this tab's default", async () => {
		const f = fake()
		expect(await main(args, f.io, env, cwd)).toBe(0)
		const assignment = f.calls[1]!.argv.find((arg) =>
			arg.startsWith("OPENCODE_CONFIG_CONTENT="),
		)!
		const config = JSON.parse(
			assignment.slice("OPENCODE_CONFIG_CONTENT=".length),
		)
		expect(Object.keys(config).sort()).toEqual([
			"$schema",
			"agent",
			"default_agent",
		])
		expect(config.default_agent).toBe(setupProfile)
		expect(Object.keys(config.agent)).toEqual([setupProfile])
		expect(config.agent[setupProfile].options.reasoningEffort).toBe("low")
		const start = f.calls[2]!.argv
		expect(start).not.toContain("--")
		expect(f.calls[3]!.argv[4]).toContain(
			"Preserve inherited implementation-worker defaults",
		)
	})

	test("only explicit opt-in permits the helper working-dependencies flag", async () => {
		const f = fake()
		expect(
			await main([...args, "--allow-working-dependencies"], f.io, env, cwd),
		).toBe(0)
		const prompt = f.calls[3]!.argv[4]!
		expect(prompt).toContain(
			"--intent launch --allow-working-dependencies exactly once",
		)
		expect(prompt).toContain(
			"ONLY if the original user request explicitly asks to start now despite existing working dependencies",
		)
		expect(prompt).toContain(
			"record that invocation-specific approval in the durable item's Important Decisions",
		)
		expect(prompt).toContain(
			"proceed without asking again about that same gate",
		)
		expect(prompt).toContain(
			"other safety checks and future invocations are not waived",
		)
		expect(f.calls.some((call) => call.argv.includes("--force"))).toBe(false)
	})

	test.each([
		{ HERDR_ENV: undefined },
		{ HERDR_ENV: "0" },
		{ HERDR_PANE_ID: undefined },
		{ HERDR_TAB_ID: "" },
		{ HERDR_WORKSPACE_ID: "" },
		{ AGENCY_SESSION_ID: "session" },
		{ AGENCY_SESSION_ID: "" },
		{ AGENCY_TARGET: "task" },
		{ AGENCY_TARGET: "" },
		{ OPENCODE_CONFIG_CONTENT: "not JSON" },
		{ OPENCODE_CONFIG_CONTENT: "[]" },
	])(
		"rejects unsafe environment before any subprocess: %j",
		async (override) => {
			const f = fake()
			expect(await main(args, f.io, { ...env, ...override }, cwd)).toBe(1)
			expect(f.calls).toHaveLength(0)
		},
	)

	test.each(
		[
			[],
			["--intent", "create", "--request", "x"],
			["--intent", "launch"],
			[...args, "--force"],
			[...args, "--cwd"],
			[...args, "--agency-executable"],
			[
				...args,
				"--agency-executable",
				"/bin/sh",
				"--agency-executable",
				"/bin/sh",
			],
			[...args, "--label", ""],
			[...args, "--intent", "open"],
			[...args, "--allow-working-dependencies", "--allow-working-dependencies"],
			["--intent", "open", "--request", " \n\t"],
			["--intent", "open", "--request", "bad\0request"],
		].map((argv) => ({ argv })),
	)("rejects invalid arguments before allocation: %j", async ({ argv }) => {
		const f = fake()
		expect(await main(argv, f.io, env, cwd)).toBe(1)
		expect(f.calls).toHaveLength(0)
	})

	test.each([1, 2, 3, 4])(
		"stops at failed command %i with no retry, focus, close, or polling",
		async (index) => {
			const f = fake({ [index]: failure })
			expect(await main(args, f.io, env, cwd)).toBe(1)
			expect(f.calls).toHaveLength(index)
			expect(f.events.at(-1)).toMatchObject({ event: "error" })
			expect(f.events.at(-1)!.recovery).toContain(
				index === 1 ? "No tab allocation" : "do not automatically retry",
			)
			if (index > 2)
				expect(f.events.at(-1)).toMatchObject({
					tabId: "w3S:t21",
					setupId: "w3S:p48",
				})
		},
	)

	test.each([1, 2, 3, 4])(
		"treats timeout/invalid JSON at step %i as failure, not success",
		async (index) => {
			for (const bad of [
				new Error("ENOENT"),
				{ status: null, stdout: "", stderr: "ETIMEDOUT" },
				{ status: 0, stdout: "not JSON", stderr: "" },
				output({ id: "cli:fake", result: { type: "ok" } }),
			]) {
				const f = fake({ [index]: bad })
				expect(await main(args, f.io, env, cwd)).toBe(1)
				expect(f.calls).toHaveLength(index)
			}
		},
	)

	test("validates caller location from live response, not an ID regex", async () => {
		for (const field of ["workspace_id", "tab_id", "pane_id"]) {
			const f = fake({
				1: output({
					...caller,
					result: {
						...caller.result,
						pane: { ...caller.result.pane, [field]: "other" },
					},
				}),
			})
			expect(await main(args, f.io, env, cwd)).toBe(1)
			expect(f.calls).toHaveLength(1)
		}
	})

	test("retains recovery IDs when allocation response has wrong identity or type", async () => {
		for (const result of [
			{ ...created.result, type: "wrong" },
			{ ...created.result, root_pane: { ...rootPane, workspace_id: "wrong" } },
			{
				...created.result,
				tab: { ...created.result.tab, workspace_id: "wrong" },
			},
			{
				...created.result,
				tab: { ...created.result.tab, tab_id: env.HERDR_TAB_ID },
			},
		]) {
			const f = fake({ 2: output({ ...created, result }) })
			expect(await main(args, f.io, env, cwd)).toBe(1)
			expect(f.calls).toHaveLength(2)
			expect(f.events.at(-1)).toMatchObject({
				tabId: result.tab.tab_id,
				setupId: "w3S:p48",
			})
		}
	})

	test("rejects success/error ambiguity even with zero exit status", async () => {
		const f = fake({ 1: output({ ...caller, error: { code: "failure" } }) })
		expect(await main(args, f.io, env, cwd)).toBe(1)
		expect(f.calls).toHaveLength(1)
	})

	test("refuses to prompt an unready or wrong setup agent", async () => {
		for (const override of [
			{ interactive_ready: false },
			{ agent: "pi" },
			{ name: "wrong" },
			{ pane_id: "wrong" },
		]) {
			const f = fake({
				3: (argv) =>
					output({
						id: "cli:agent:start",
						result: {
							type: "agent_started",
							agent: { ...agent, name: argv[3], ...override },
						},
					}),
			})
			expect(await main(args, f.io, env, cwd)).toBe(1)
			expect(f.calls).toHaveLength(3)
		}
	})

	test("rejects different native argv before submitting the request", async () => {
		const f = fake({
			3: (argv) =>
				output({
					id: "cli:agent:start",
					result: {
						type: "agent_started",
						agent: { ...agent, name: argv[3] },
						argv: ["opencode", "mini"],
					},
				}),
		})
		expect(await main(args, f.io, env, cwd)).toBe(1)
		expect(f.calls).toHaveLength(3)
		expect(f.events.at(-1)!.message).toBe("Unexpected setup agent argv")
	})

	test("rejects prompt acceptance by another pane or occupant without retry", async () => {
		for (const override of [
			{ pane_id: "other-pane" },
			{ name: "another-agent" },
			{ agent: "pi" },
		]) {
			const f = fake({
				4: (argv) =>
					output({
						id: "cli:agent:prompt",
						result: {
							type: "agent_prompted",
							agent: { ...agent, name: argv[3], ...override },
						},
					}),
			})
			expect(await main(args, f.io, env, cwd)).toBe(1)
			expect(f.calls).toHaveLength(4)
			expect(f.events.at(-1)!.event).toBe("error")
		}
	})
})

// Optional source contract test; no CLI calls, network, or launches. The source
// checkout must have its own dependencies installed. Never install them here.
test.skipIf(!process.env.OPENCODE_SOURCE_DIR)(
	"OpenCode's config and request pipeline keep the full TUI setup profile low",
	async () => {
		const root = resolve(process.env.OPENCODE_SOURCE_DIR!)
		const { Schema, Effect } = await import(
			Bun.resolveSync("effect", `${root}/packages/core`)
		)
		const { ConfigAgentV1 } = await import(
			`${root}/packages/core/src/v1/config/agent.ts`
		)
		const profile = Schema.decodeUnknownSync(ConfigAgentV1.Info)(
			setupConfig.agent[setupProfile],
		)
		// Independent expected values, not merely a schema acceptance assertion.
		expect(profile.options.reasoningEffort).toBe("low")
		expect(profile.variant).toBe("low")
		expect(profile.model).toBe("openai/gpt-5.6-sol")
		expect(profile.mode).toBe("primary")
		expect(setupConfig.default_agent).toBe(setupProfile)
		const { ConfigParse } = await import(
			`${root}/packages/opencode/src/config/parse.ts`
		)
		expect(
			ConfigParse.jsonc(inheritedJsonc, "OPENCODE_CONFIG_CONTENT")
				.default_agent,
		).toBe("implementation")
		const { prepare } = await import(
			`${root}/packages/opencode/src/session/llm/request.ts`
		)
		const { ProviderTransform } = await import(
			`${root}/packages/opencode/src/provider/transform.ts`
		)
		const model = {
			id: "gpt-5.6-sol",
			providerID: "openai",
			api: {
				id: "gpt-5.6-sol",
				npm: "@ai-sdk/openai",
				url: "https://api.openai.com/v1",
			},
			capabilities: { reasoning: true, temperature: false },
			options: { reasoningEffort: "high" },
			limit: { context: 200000, output: 32000 },
			headers: {},
		}
		const variants = ProviderTransform.variants(model)
		expect(variants.low.reasoningEffort).toBe("low")
		const f = fake()
		expect(await main(args, f.io, env, cwd)).toBe(0)
		const start = f.calls[2]!.argv
		expect(start).not.toContain("--")
		const prepared = await Effect.runPromise(
			prepare({
				user: { id: "test-message", model: { variant: profile.variant } },
				sessionID: "test-session",
				model: { ...model, variants },
				agent: {
					...profile,
					name: setupProfile,
					prompt: "Setup",
					permission: [],
				},
				provider: { id: "openai", options: {} },
				system: [],
				messages: [],
				tools: {},
				flags: {},
				isWorkflow: false,
				plugin: {
					trigger: (_name: string, _input: unknown, output: unknown) =>
						Effect.succeed(output),
				},
			}),
		)
		expect(prepared.params.options.reasoningEffort).toBe("low")
	},
)
