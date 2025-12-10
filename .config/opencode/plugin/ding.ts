import type { Plugin } from "@opencode-ai/plugin"

export const Ding: Plugin = async ({ $, client }) => {
	return {
		async event({ event }) {
			if (event.type === "session.idle") {
				const { sessionID } = event.properties
				const { data: session } = await client.session.get({
					path: { id: sessionID },
				})

				if (!session) return

				const isSubagent = !!session.parentID

				if (isSubagent) return

				await $`afplay /System/Library/Sounds/Glass.aiff`
			}
		},
	}
}
