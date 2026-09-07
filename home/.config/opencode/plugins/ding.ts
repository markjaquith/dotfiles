import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { Plugin } from "@opencode-ai/plugin"

const exec = promisify(execFile)

const COMPLETION_SOUND = "/System/Library/Sounds/Glass.aiff"
const ATTENTION_SOUND = "/System/Library/Sounds/Ping.aiff"
const OPENCODE_PROCESS_ROLE = "OPENCODE_PROCESS_ROLE"
const OPENCODE_DING = "OPENCODE_DING"

function shouldPlayDings() {
	if (process.env[OPENCODE_DING] === "1") {
		return true
	}

	if (process.env[OPENCODE_DING] === "0") {
		return false
	}

	// The TUI runs server plugins in its worker; standalone servers should stay silent.
	return process.env[OPENCODE_PROCESS_ROLE] === "worker"
}

export const Ding = Plugin.define({
	id: "ding",
	async setup({ event, session, tool, location }) {
		if (!shouldPlayDings()) return

		const controller = new AbortController()
		const { signal } = controller
		const lastDingBySession = new Map<string, string>()
		const sounds = new Set<Promise<void>>()
		function playSound(sound: string) {
			if (signal.aborted) return Promise.resolve()
			const playing = exec("afplay", [sound], { signal })
				.then(() => {})
				.catch((error: unknown) => {
					if (!signal.aborted) console.error("[ding] Sound failed", error)
				})
				.finally(() => sounds.delete(playing))
			sounds.add(playing)
			return playing
		}
		const question = await tool.hook("execute.before", async (input) => {
			if (input.tool === "question") await playSound(ATTENTION_SOUND)
		})
		const listening = (async () => {
			for await (const item of event.subscribe({ signal })) {
				if (signal.aborted) break
				if (
					item.location &&
					(item.location.directory !== location.directory ||
						item.location.workspaceID !== location.workspaceID)
				)
					continue
				try {
					if (item.type === "permission.asked") {
						await playSound(ATTENTION_SOUND)
						continue
					}
					if (item.type === "session.deleted") {
						lastDingBySession.delete(item.data.sessionID)
						continue
					}
					if (
						item.type !== "session.status" ||
						item.data.status.type !== "idle"
					)
						continue
					const { sessionID } = item.data
					const info = await session.get({ sessionID })
					if (signal.aborted || info.parentID) continue
					const messages = await session.context({ sessionID })
					const last = messages.findLast(
						(message) =>
							message.type === "user" || message.type === "assistant",
					)
					if (signal.aborted || last?.type !== "assistant" || last.error)
						continue
					if (lastDingBySession.get(sessionID) === last.id) continue
					lastDingBySession.set(sessionID, last.id)
					await playSound(COMPLETION_SOUND)
				} catch (error) {
					if (!signal.aborted) console.error("[ding] Event failed", error)
				}
			}
		})().catch((error: unknown) => {
			if (!signal.aborted) console.error("[ding] Event stream failed", error)
		})
		return async () => {
			controller.abort()
			await Promise.all([question.dispose(), listening, ...sounds])
			lastDingBySession.clear()
		}
	},
})

export default Ding
