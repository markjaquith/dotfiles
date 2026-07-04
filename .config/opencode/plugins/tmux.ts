import type { Plugin } from "@opencode-ai/plugin"

const COMMAND_NAME = "herdr"
const OPENCODE_COMMAND_MATCH = "opencode"

type CommandPart = {
	type: string
	ignored?: boolean
	text?: string
}

type Pane = {
	paneId: string
	command?: string
	agent?: string
}

type Json = null | boolean | number | string | Json[] | { [key: string]: Json }

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
	const [paneId, command] = line.split("\t")
	if (!paneId || !command) {
		return null
	}

	return { paneId, command }
}

function usage() {
	return "Usage: `/herdr others {message to send to other OpenCode panes}`"
}

function isJsonObject(value: Json): value is { [key: string]: Json } {
	return value !== null && typeof value === "object" && !Array.isArray(value)
}

function stringValue(object: { [key: string]: Json }, key: string) {
	const value = object[key]
	return typeof value === "string" ? value : undefined
}

function collectPanes(value: Json, panes: Pane[]) {
	if (Array.isArray(value)) {
		for (const item of value) {
			collectPanes(item, panes)
		}
		return
	}

	if (!isJsonObject(value)) {
		return
	}

	const paneId =
		stringValue(value, "pane_id") ??
		stringValue(value, "paneId") ??
		stringValue(value, "id")
	if (paneId) {
		panes.push({
			paneId,
			command:
				stringValue(value, "command") ??
				stringValue(value, "name") ??
				stringValue(value, "process") ??
				stringValue(value, "foreground_command"),
			agent:
				stringValue(value, "agent") ??
				stringValue(value, "label") ??
				stringValue(value, "agent_label"),
		})
	}

	for (const nested of Object.values(value)) {
		collectPanes(nested, panes)
	}
}

function parseJsonPanes(text: string) {
	const parsed = JSON.parse(text) as Json
	const panes: Pane[] = []
	collectPanes(parsed, panes)

	return panes
}

function looksLikeOpenCode(pane: Pane) {
	return [pane.agent, pane.command]
		.filter((value): value is string => typeof value === "string")
		.some((value) => value.toLowerCase().includes(OPENCODE_COMMAND_MATCH))
}

export const HerdrPlugin: Plugin = async ({ $ }) => {
	async function candidateOpenCodePanes() {
		try {
			const agents = await $`herdr agent list`.text()
			const panes = parseJsonPanes(agents).filter(looksLikeOpenCode)
			if (panes.length > 0) {
				return panes
			}
		} catch {
			// Fall back to pane inspection for older or differently formatted CLIs.
		}

		try {
			const panes = await $`herdr pane list`.text()
			return parseJsonPanes(panes).filter(looksLikeOpenCode)
		} catch {
			const panes = await $`herdr pane list`.text()

			return panes
				.split("\n")
				.map((line) => parsePane(line))
				.filter((pane): pane is Pane => pane !== null)
				.filter(looksLikeOpenCode)
		}
	}

	async function otherOpenCodePanes() {
		const currentPaneId = process.env.HERDR_PANE_ID
		const panes = await candidateOpenCodePanes()

		return panes.filter((pane) => pane.paneId !== currentPaneId)
	}

	async function sendToPane(pane: Pane, message: string) {
		await $`herdr pane send-text ${pane.paneId} ${message}`.quiet()
		await $`herdr pane send-keys ${pane.paneId} enter`.quiet()
	}

	async function sendToOthers(message: string) {
		if (!process.env.HERDR_ENV && !process.env.HERDR_PANE_ID) {
			throw new Error("Not inside Herdr.")
		}

		const panes = await otherOpenCodePanes()
		if (panes.length === 0) {
			throw new Error(
				"No other OpenCode panes found in the current Herdr session.",
			)
		}

		await Promise.all(panes.map((pane) => sendToPane(pane, message)))
		return panes.length
	}

	return {
		async config(config) {
			config.command ??= {}
			config.command[COMMAND_NAME] = {
				description: "Control other Herdr panes",
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
					`The Herdr message was sent to ${paneCount} other OpenCode pane${paneCount === 1 ? "" : "s"}. Do not run tools. Reply only with: Sent.`,
				)
			} catch (error) {
				replaceCommandText(
					output.parts,
					`Failed to run /herdr others: ${error instanceof Error ? error.message : String(error)}`,
				)
			}
		},
	}
}
