import { readFile } from "node:fs/promises"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { parseFrontmatter } from "@earendil-works/pi-coding-agent"
import { Text } from "@earendil-works/pi-tui"

const COLLAPSED_PROMPT_TYPE = "collapsed-prompt"

export type PromptInvocation = {
	name: string
	argsString: string
}

export function parsePromptInvocation(
	text: string,
): PromptInvocation | undefined {
	const match = text.match(/^\/([^\s]+)(?:\s+([\s\S]*))?$/)
	if (!match?.[1]) return

	return {
		name: match[1],
		argsString: match[2] ?? "",
	}
}

export function parsePromptArgs(argsString: string): string[] {
	const args: string[] = []
	let current = ""
	let quote: '"' | "'" | undefined

	for (const character of argsString) {
		if (quote) {
			if (character === quote) quote = undefined
			else current += character
		} else if (character === '"' || character === "'") {
			quote = character
		} else if (/\s/.test(character)) {
			if (!current) continue
			args.push(current)
			current = ""
		} else {
			current += character
		}
	}

	if (current) args.push(current)
	return args
}

export function substitutePromptArgs(content: string, args: string[]): string {
	const allArgs = args.join(" ")

	return content.replace(
		/\$\{(\d+|ARGUMENTS|@):-([^}]*)\}|\$\{@:(\d+)(?::(\d+))?\}|\$(ARGUMENTS|@|\d+)/g,
		(_match, defaultTarget, defaultValue, sliceStart, sliceLength, simple) => {
			if (defaultTarget) {
				const value =
					defaultTarget === "@" || defaultTarget === "ARGUMENTS"
						? allArgs
						: args[Number.parseInt(defaultTarget, 10) - 1]
				return value || defaultValue
			}

			if (sliceStart) {
				const start = Math.max(Number.parseInt(sliceStart, 10) - 1, 0)
				if (sliceLength) {
					const length = Number.parseInt(sliceLength, 10)
					return args.slice(start, start + length).join(" ")
				}
				return args.slice(start).join(" ")
			}

			if (simple === "ARGUMENTS" || simple === "@") return allArgs
			return args[Number.parseInt(simple, 10) - 1] ?? ""
		},
	)
}

export function expandPrompt(rawContent: string, argsString: string): string {
	const { body } = parseFrontmatter(rawContent)
	return substitutePromptArgs(body, parsePromptArgs(argsString))
}

export default function (pi: ExtensionAPI) {
	pi.registerMessageRenderer(
		COLLAPSED_PROMPT_TYPE,
		(message, { outputPad }, theme) => {
			const details = message.details as { command?: unknown } | undefined
			const command =
				typeof details?.command === "string" ? details.command : "/prompt"
			return new Text(theme.fg("muted", command), outputPad, 0)
		},
	)

	pi.on("input", async (event, ctx) => {
		if (ctx.mode !== "tui") return { action: "continue" }

		const invocation = parsePromptInvocation(event.text)
		if (!invocation) return { action: "continue" }

		const prompt = pi
			.getCommands()
			.find(
				(command) =>
					command.source === "prompt" && command.name === invocation.name,
			)
		if (!prompt) return { action: "continue" }

		let rawContent: string
		try {
			rawContent = await readFile(prompt.sourceInfo.path, "utf8")
		} catch {
			return { action: "continue" }
		}

		const expandedPrompt = expandPrompt(rawContent, invocation.argsString)
		const content = event.images?.length
			? [{ type: "text" as const, text: expandedPrompt }, ...event.images]
			: expandedPrompt

		pi.sendMessage(
			{
				customType: COLLAPSED_PROMPT_TYPE,
				content,
				display: true,
				details: { command: `/${invocation.name}` },
			},
			{
				triggerTurn: true,
				...(event.streamingBehavior && {
					deliverAs: event.streamingBehavior,
				}),
			},
		)

		return { action: "handled" }
	})
}
