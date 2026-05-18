import type { Plugin } from "@opencode-ai/plugin"

const COMPLETION_SOUND = "/System/Library/Sounds/Glass.aiff"
const ATTENTION_SOUND = "/System/Library/Sounds/Ping.aiff"

const lastDingBySession = new Map<string, string>()

export const Ding: Plugin = async ({ $, client }) => {
	async function playSound(sound: string) {
		await $`afplay ${sound}`
	}

	return {
		async "permission.ask"() {
			await playSound(ATTENTION_SOUND)
		},

		async "tool.execute.before"(input) {
			if (input.tool !== "question") {
				return
			}

			await playSound(ATTENTION_SOUND)
		},

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

			await playSound(COMPLETION_SOUND)
		},
	}
}
