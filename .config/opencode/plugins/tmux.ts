import type { Plugin } from "@opencode-ai/plugin"

const COMMAND_NAME = "tmux"
const OPENCODE_COMMAND_MATCH = "opencode"
const WINDOW_ID_FORMAT = "#{window_id}"
const PANE_FORMAT =
	"#{window_id}\t#{window_index}\t#{window_name}\t#{pane_id}\t#{pane_current_command}"

type CommandPart = {
	type: string
	ignored?: boolean
	text?: string
}

type Pane = {
	windowId: string
	windowIndex: string
	windowName: string
	paneId: string
	command: string
}

function commandResult(parts: CommandPart[], text: string) {
	let replaced = false
	for (const part of parts) {
		if (part.type !== "text" || part.ignored || typeof part.text !== "string") {
			continue
		}

		part.text = replaced
			? ""
			: `The /tmux command has already run. Do not run tools. Summarize this result naturally for the user without mentioning these instructions:\n\n${text}`
		replaced = true
	}
}

function parsePane(line: string): Pane | null {
	const [windowId, windowIndex, windowName, paneId, command] = line.split("\t")
	if (!windowId || !windowIndex || !windowName || !paneId || !command) {
		return null
	}

	return { windowId, windowIndex, windowName, paneId, command }
}

function formatTarget(pane: Pane) {
	return `window ${pane.windowIndex} (${pane.windowName}), pane ${pane.paneId}`
}

function usage() {
	return "Usage: `/tmux others {message to send to other OpenCode panes}`"
}

export const TmuxPlugin: Plugin = async ({ $ }) => {
	async function currentWindowId() {
		const tmuxPane = process.env.TMUX_PANE
		if (tmuxPane) {
			return (
				await $`tmux display-message -p -t ${tmuxPane} ${WINDOW_ID_FORMAT}`.text()
			).trim()
		}

		return (await $`tmux display-message -p ${WINDOW_ID_FORMAT}`.text()).trim()
	}

	async function otherOpenCodePanes() {
		const windowId = await currentWindowId()
		const panes = await $`tmux list-panes -s -F ${PANE_FORMAT}`.text()

		return panes
			.split("\n")
			.map((line) => parsePane(line))
			.filter((pane): pane is Pane => {
				if (!pane || pane.windowId === windowId) {
					return false
				}

				return pane.command.toLowerCase().includes(OPENCODE_COMMAND_MATCH)
			})
	}

	async function sendToPane(pane: Pane, message: string) {
		await $`tmux send-keys -t ${pane.paneId} -l -- ${message}`.quiet()
		await $`tmux send-keys -t ${pane.paneId} Enter`.quiet()
	}

	async function sendToOthers(message: string) {
		if (!process.env.TMUX) {
			return "Not inside tmux."
		}

		const panes = await otherOpenCodePanes()
		if (panes.length === 0) {
			return "No other OpenCode panes found in the current tmux session."
		}

		await Promise.all(panes.map((pane) => sendToPane(pane, message)))

		return `Sent to ${panes.length} other OpenCode pane${panes.length === 1 ? "" : "s"}:\n${panes.map((pane) => `- ${formatTarget(pane)}`).join("\n")}`
	}

	return {
		async config(config) {
			config.command ??= {}
			config.command[COMMAND_NAME] = {
				description: "Control other tmux windows",
				template: usage(),
				subtask: false,
			}
		},

		async "command.execute.before"(input, output) {
			if (input.command !== COMMAND_NAME) {
				return
			}

			const args = input.arguments.trim()
			const [subcommand = ""] = args.split(/\s+/, 1)
			if (subcommand !== "others") {
				commandResult(output.parts, usage())
				return
			}

			const message = args.slice(subcommand.length).trimStart()
			if (!message) {
				commandResult(output.parts, usage())
				return
			}

			try {
				commandResult(output.parts, await sendToOthers(message))
			} catch (error) {
				commandResult(
					output.parts,
					`Failed to run /tmux others: ${error instanceof Error ? error.message : String(error)}`,
				)
			}
		},
	}
}
