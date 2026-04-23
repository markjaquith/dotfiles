import type { Plugin } from "@opencode-ai/plugin"

const lastDingBySession = new Map<string, string>()

export const Ding: Plugin = async ({ $, client }) => {
	return {
		async event({ event }) {
			if (event.type !== "session.idle") {
				return
			}

			const { sessionID } = event.properties

			const [{ data: session }, { data: messages = [] }] = await Promise.all([
				client.session.get({ path: { id: sessionID } }),
				client.session.messages({ path: { id: sessionID } }),
			])

			if (!session || session.parentID) {
				return
			}

			const lastMessage = messages.at(-1)
			if (!lastMessage || lastMessage.info.role !== "assistant") {
				return
			}

			if (lastMessage.info.error) {
				return
			}

			if (lastDingBySession.get(sessionID) === lastMessage.info.id) {
				return
			}

			lastDingBySession.set(sessionID, lastMessage.info.id)

			await $`afplay /System/Library/Sounds/Glass.aiff`
		},
	}
}
