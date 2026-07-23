import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"

const MAX_INLINE_CHARACTERS = 2048
const SUMMARY_LINE_THRESHOLD = 10
const PASTE_SUMMARY_KEY = "paste_summary_enabled"

function normalizePaste(bytes: Uint8Array) {
	return new TextDecoder()
		.decode(bytes)
		.replace(/\r\n/g, "\n")
		.replace(/\r/g, "\n")
		.trim()
}

export function shouldSummarizePaste(text: string) {
	const lineCount = (text.match(/\n/g)?.length ?? 0) + 1
	return (
		lineCount >= SUMMARY_LINE_THRESHOLD || text.length > MAX_INLINE_CHARACTERS
	)
}

export const PasteSummaryThreshold: TuiPlugin = async (api) => {
	const onPaste = (event: { bytes: Uint8Array }) => {
		if (
			api.route.current.name !== "home" &&
			api.route.current.name !== "session"
		) {
			return
		}

		const summarize = shouldSummarizePaste(normalizePaste(event.bytes))
		if (api.kv.get(PASTE_SUMMARY_KEY) === summarize) {
			return
		}

		api.kv.set(PASTE_SUMMARY_KEY, summarize)
	}

	api.renderer.keyInput.on("paste", onPaste)
	api.lifecycle.onDispose(() => api.renderer.keyInput.off("paste", onPaste))
}

const plugin: TuiPluginModule & { id: string } = {
	id: "paste-summary-threshold",
	tui: PasteSummaryThreshold,
}

export default plugin
