import { existsSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { normalizePaste, shouldKeepPasteInline } from "./policy.js"

/** @param {string} value */
function pastedFilepath(value) {
	const raw = value.trim().replace(/^['"]+|['"]+$/g, "")
	if (raw.startsWith("file://")) {
		try {
			return fileURLToPath(raw)
		} catch {
			return raw
		}
	}
	return process.platform === "win32" ? raw : raw.replace(/\\(.)/g, "$1")
}

/** @param {string} text @param {string} directory */
function isLocalFilePaste(text, directory) {
	const value = pastedFilepath(text)
	if (!value || /\n/.test(value) || /^https?:\/\//.test(value)) return false
	return existsSync(path.resolve(directory, value))
}

export default {
	id: "paste-summary-threshold",
	setup(context) {
		/** @param {import("@opentui/core").PasteEvent} event */
		const onPaste = (event) => {
			if (event.type !== "paste") return
			if (event.metadata?.kind === "binary") return

			const route = context.ui.router.current()
			if (route.type !== "home" && route.type !== "session") return
			if (
				!context.keymap
					.commands()
					.some((command) => command.id === "prompt.paste")
			) {
				return
			}

			const text = normalizePaste(event.bytes)
			if (!shouldKeepPasteInline(text)) return

			const directory = context.location?.directory ?? process.cwd()
			if (isLocalFilePaste(text, directory)) return

			const editor = context.renderer.currentFocusedEditor
			if (!editor) return

			event.preventDefault()
			editor.insertText(text)
		}

		context.renderer.keyInput.on("paste", onPaste)
		return () => context.renderer.keyInput.off("paste", onPaste)
	},
}
