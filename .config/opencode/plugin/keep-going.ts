import type { Plugin } from "@opencode-ai/plugin"

const COMMAND_NAME = "keep-going"
const KEEP_GOING_PROMPT =
	"Keep going. If you are well and truly done, respond with the text 'I AM DONE' and ONLY that text."
const DONE_TEXT = "I AM DONE"

const activeSessions = new Set<string>()
const replayingSessions = new Set<string>()

type MessagePart = {
	type: string
	ignored?: boolean
	text?: string
}

function getPromptText(parts: MessagePart[]) {
	return parts
		.filter(
			(part): part is MessagePart & { type: "text"; text: string } =>
				part.type === "text" && !part.ignored && typeof part.text === "string",
		)
		.map((part) => part.text)
		.join("\n")
		.trim()
}

function isKeepGoingPrompt(parts: MessagePart[]) {
	return getPromptText(parts) === KEEP_GOING_PROMPT
}

function assistantIsDone(parts: MessagePart[]) {
	const text = getPromptText(parts)
	if (text !== DONE_TEXT) {
		return false
	}

	return !parts.some((part) => {
		if (part.type === "text") {
			return false
		}

		return ![
			"reasoning",
			"step-start",
			"step-finish",
			"retry",
			"compaction",
			"snapshot",
		].includes(part.type)
	})
}

async function sendKeepGoing(
	client: Parameters<Plugin>[0]["client"],
	sessionID: string,
) {
	await client.session.prompt({
		path: { id: sessionID },
		body: {
			parts: [{ type: "text", text: KEEP_GOING_PROMPT }],
		},
	})
}

export const KeepGoingPlugin: Plugin = async ({ client }) => {
	return {
		async config(config) {
			config.command ??= {}
			config.command[COMMAND_NAME] = {
				description: "Keep going until truly done",
				template: KEEP_GOING_PROMPT,
				subtask: false,
			}
		},

		async "command.execute.before"(input) {
			if (input.command !== COMMAND_NAME) {
				return
			}

			activeSessions.add(input.sessionID)
		},

		async "chat.message"(input, output) {
			if (!activeSessions.has(input.sessionID)) {
				return
			}

			if (!isKeepGoingPrompt(output.parts)) {
				activeSessions.delete(input.sessionID)
				replayingSessions.delete(input.sessionID)
			}
		},

		async event({ event }) {
			if (event.type !== "session.idle") {
				return
			}

			const { sessionID } = event.properties
			if (!activeSessions.has(sessionID) || replayingSessions.has(sessionID)) {
				return
			}

			replayingSessions.add(sessionID)

			try {
				const { data: messages = [] } = await client.session.messages({
					path: { id: sessionID },
				})

				const lastAssistantMessage = [...messages].reverse().find(
					(
						message,
					): message is (typeof messages)[number] & {
						info: { role: "assistant"; error?: unknown }
					} => message.info.role === "assistant",
				)

				if (!lastAssistantMessage || lastAssistantMessage.info.error) {
					return
				}

				if (assistantIsDone(lastAssistantMessage.parts)) {
					activeSessions.delete(sessionID)
					return
				}

				await sendKeepGoing(client, sessionID)
			} finally {
				replayingSessions.delete(sessionID)
			}
		},
	}
}
