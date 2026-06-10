import type { Plugin } from "@opencode-ai/plugin"

const COMMAND_NAME = "tmux"
const OPENCODE_COMMAND_MATCH = "opencode"
const WINDOW_ID_FORMAT = "#{window_id}"
const PANE_FORMAT = "#{window_id}\t#{pane_id}\t#{pane_current_command}"

type CommandPart = {
	type: string
	ignored?: boolean
	text?: string
}

type Pane = {
	windowId: string
	paneId: string
	command: string
}

function replaceCommandText(parts: CommandPart[], text: string) {
	let replaced = false
	for (const part of parts) {
		if (part.type !== "text" || part.ignored || typeof part.text !== "string") {
			continue
		}

		part.text = replaced ? "" : text
		replaced = true
	}
}

function parsePane(line: string): Pane | null {
	const [windowId, paneId, command] = line.split("\t")
	if (!windowId || !paneId || !command) {
		return null
	}

	return { windowId, paneId, command }
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
			throw new Error("Not inside tmux.")
		}

		const panes = await otherOpenCodePanes()
		if (panes.length === 0) {
			throw new Error(
				"No other OpenCode panes found in the current tmux session.",
			)
		}

		await Promise.all(panes.map((pane) => sendToPane(pane, message)))
		return panes.length
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
				replaceCommandText(output.parts, usage())
				return
			}

			const message = args.slice(subcommand.length).trimStart()
			if (!message) {
				replaceCommandText(output.parts, usage())
				return
			}

			try {
				const paneCount = await sendToOthers(message)
				replaceCommandText(
					output.parts,
					`The tmux message was sent to ${paneCount} other OpenCode pane${paneCount === 1 ? "" : "s"}. Do not run tools. Reply only with: Sent.`,
				)
			} catch (error) {
				replaceCommandText(
					output.parts,
					`Failed to run /tmux others: ${error instanceof Error ? error.message : String(error)}`,
				)
			}
		},
	}
}
