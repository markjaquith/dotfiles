import type { Plugin } from "@opencode-ai/plugin"

const isTUI = process.argv[2] !== "run"

export const Ding: Plugin = async ({ $, client }) => {
	// Track sessions that the TUI user has interacted with.
	// When we see a tui prompt.submit, we flag that the next UserMessage
	// belongs to the TUI. We then record that session ID so we only ding
	// for sessions the TUI user actually prompted.
	const tuiSessions = new Set<string>()
	let expectingTuiMessage = false

	return {
		async event({ event }) {
			if (event.type === "tui.command.execute") {
				if (event.properties.command === "prompt.submit") {
					expectingTuiMessage = true
				}
				return
			}

			if (event.type === "message.updated") {
				const msg = event.properties.info
				if (msg.role === "user" && expectingTuiMessage) {
					tuiSessions.add(msg.sessionID)
					expectingTuiMessage = false
				}
				return
			}

			if (event.type === "session.idle") {
				if (!isTUI) return

				const { sessionID } = event.properties

				if (!tuiSessions.has(sessionID)) return

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
