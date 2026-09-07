import { Plugin } from "@opencode-ai/plugin"

const COMMAND_NAME = "keep-going"
const KEEP_GOING_PROMPT =
	"Keep going with remaining tasks. If you are well and truly done with this task, and have conclusively done all that you can, respond with the text 'I AM DONE' and ONLY that text."
const DONE_TEXT = "I AM DONE"

export const KeepGoingPlugin = Plugin.define({
	id: "keep-going",
	async setup({ command, session, event, location }) {
		const controller = new AbortController()
		const { signal } = controller
		const activeSessions = new Map<string, { lastReply?: string }>()
		const commands = await command.transform((editor) => {
			editor.add({
				name: COMMAND_NAME,
				description: "Keep going until truly done",
				async execute({ sessionID, prompt, delivery }) {
					if (signal.aborted) return
					const active = {}
					activeSessions.set(sessionID, active)
					try {
						await session.prompt({
							...prompt,
							sessionID,
							text: KEEP_GOING_PROMPT,
							delivery,
						})
					} catch (error) {
						if (activeSessions.get(sessionID) === active)
							activeSessions.delete(sessionID)
						throw error
					}
				},
			})
		})
		const prompts = await session
			.hook("prompt", ({ sessionID, prompt }) => {
				if (prompt.text.trim() !== KEEP_GOING_PROMPT)
					activeSessions.delete(sessionID)
			})
			.catch(async (error: unknown) => {
				await commands.dispose()
				throw error
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
				if (item.type === "session.deleted") {
					activeSessions.delete(item.data.sessionID)
					continue
				}
				if (item.type !== "session.status" || item.data.status.type !== "idle")
					continue
				const { sessionID } = item.data
				const active = activeSessions.get(sessionID)
				if (!active) continue
				try {
					const messages = await session.context({ sessionID })
					// A user prompt can cancel or restart the loop while context is loading.
					if (signal.aborted || activeSessions.get(sessionID) !== active)
						continue
					const conversation = messages.filter(
						(message) =>
							message.type === "user" || message.type === "assistant",
					)
					const last = conversation.at(-1)
					const user = conversation.findLast(
						(message) => message.type === "user",
					)
					if (
						last?.type === "assistant" &&
						!last.error &&
						user?.text.trim() === KEEP_GOING_PROMPT &&
						last.content
							.filter((part) => part.type === "text")
							.map((part) => part.text)
							.join("\n")
							.trim() === DONE_TEXT &&
						!last.content.some((part) => part.type === "tool")
					) {
						activeSessions.delete(sessionID)
						continue
					}
					// Prompt now enqueues immediately, so repeated idle events need a watermark.
					const reply =
						conversation.findLast((message) => message.type === "assistant")
							?.id ?? ""
					if (active.lastReply === reply) continue
					await session.prompt({ sessionID, text: KEEP_GOING_PROMPT })
					active.lastReply = reply
				} catch (error) {
					if (!signal.aborted)
						console.error("[keep-going] Replay failed", error)
				}
			}
		})().catch((error: unknown) => {
			if (!signal.aborted)
				console.error("[keep-going] Event stream failed", error)
		})
		return async () => {
			controller.abort()
			activeSessions.clear()
			await Promise.all([commands.dispose(), prompts.dispose(), listening])
		}
	},
})

export default KeepGoingPlugin
