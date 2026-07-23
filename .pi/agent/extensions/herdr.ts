import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const COMMAND_NAME = "herdr"

type HerdrAgent = {
	agent?: string
	pane_id?: string
	workspace_id?: string
}

function parseAgents(output: string): HerdrAgent[] {
	try {
		const parsed = JSON.parse(output) as {
			result?: { agents?: HerdrAgent[] }
		}
		return parsed.result?.agents ?? []
	} catch {
		return []
	}
}

function usage() {
	return "Usage: /herdr others <message to send to other Pi panes>"
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand(COMMAND_NAME, {
		description: "Send a message to other Pi panes in this Herdr workspace",
		getArgumentCompletions: (prefix) => {
			if ("others".startsWith(prefix)) {
				return [{ value: "others", label: "others" }]
			}
			return null
		},
		handler: async (args, ctx) => {
			if (
				process.env.HERDR_ENV !== "1" ||
				!process.env.HERDR_PANE_ID ||
				!process.env.HERDR_WORKSPACE_ID
			) {
				ctx.ui.notify("Not inside a Herdr-managed pane.", "error")
				return
			}

			const [subcommand = "", ...messageParts] = args.trim().split(/\s+/)
			const message = messageParts.join(" ")
			if (subcommand !== "others" || !message) {
				ctx.ui.notify(usage(), "warning")
				return
			}

			const listed = await pi.exec("herdr", ["agent", "list"], {
				timeout: 5_000,
			})
			if (listed.code !== 0) {
				ctx.ui.notify(
					`Failed to list Herdr agents: ${listed.stderr.trim() || `exit ${listed.code}`}`,
					"error",
				)
				return
			}

			const targets = parseAgents(listed.stdout).filter(
				(agent): agent is HerdrAgent & { pane_id: string } =>
					agent.agent === "pi" &&
					typeof agent.pane_id === "string" &&
					agent.pane_id !== process.env.HERDR_PANE_ID &&
					agent.workspace_id === process.env.HERDR_WORKSPACE_ID,
			)

			if (targets.length === 0) {
				ctx.ui.notify(
					"No other Pi panes found in the current Herdr workspace.",
					"warning",
				)
				return
			}

			const results = await Promise.all(
				targets.map(async ({ pane_id }) => ({
					paneId: pane_id,
					result: await pi.exec(
						"herdr",
						["agent", "prompt", pane_id, message],
						{
							timeout: 10_000,
						},
					),
				})),
			)
			const failures = results.filter(({ result }) => result.code !== 0)

			if (failures.length > 0) {
				const failedPanes = failures.map(({ paneId }) => paneId).join(", ")
				ctx.ui.notify(
					`Sent to ${targets.length - failures.length}/${targets.length} Pi panes. Failed: ${failedPanes}`,
					"warning",
				)
				return
			}

			ctx.ui.notify(
				`Sent to ${targets.length} other Pi pane${targets.length === 1 ? "" : "s"}.`,
				"info",
			)
		},
	})
}
