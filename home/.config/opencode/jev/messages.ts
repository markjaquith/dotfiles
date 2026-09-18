import type { SessionMessageInfo } from "@opencode-ai/client"

export interface JevMessage {
	role: "user" | "assistant"
	content: unknown
}

export function lastConversationMessages(
	messages: readonly SessionMessageInfo[],
): JevMessage[] {
	return messages
		.filter(
			(message) => message.type === "user" || message.type === "assistant",
		)
		.slice(-4)
		.map((message) => {
			if (message.type === "user") {
				return { role: "user", content: message.text }
			}

			return {
				role: "assistant",
				content: message.content.filter((part) => part.type !== "reasoning"),
			}
		})
}
