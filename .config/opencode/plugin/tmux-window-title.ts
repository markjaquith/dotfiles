import { execFileSync, spawn } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

const isTUI = !process.argv[2] || process.argv[2].startsWith("-")
let releaseTitleOnExit = false
let didReleaseTitle = false
let targetWindow: string | undefined

function releaseWindowTitle() {
	if (!releaseTitleOnExit || didReleaseTitle) {
		return
	}
	didReleaseTitle = true

	try {
		const setAutomaticRenameOnArgs = targetWindow
			? ["set-window-option", "-t", targetWindow, "automatic-rename", "on"]
			: ["set-window-option", "automatic-rename", "on"]
		execFileSync("tmux", setAutomaticRenameOnArgs, { stdio: "ignore" })
		execFileSync("tmux", ["refresh-client", "-S"], { stdio: "ignore" })
	} catch {}
}

function scheduleWindowTitleRelease(windowID: string) {
	const script = [
		`pid=${process.pid}`,
		`window='${windowID}'`,
		'while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done',
		'tmux set-window-option -t "$window" automatic-rename on >/dev/null 2>&1',
		"tmux refresh-client -S >/dev/null 2>&1",
	].join("; ")

	const watcher = spawn("sh", ["-c", script], {
		detached: true,
		stdio: "ignore",
	})

	watcher.unref()
}

export const TmuxWindowTitlePlugin: Plugin = async () => {
	if (!isTUI || !process.env.TMUX) {
		return {}
	}

	try {
		const [windowID = "", windowTitle = "", automaticRename = ""] =
			execFileSync(
				"tmux",
				["display-message", "-p", "#{window_id}\t#W\t#{automatic-rename}"],
				{
					encoding: "utf8",
				},
			)
				.trim()
				.split("\t")

		const shouldRenameToOpenCode = windowTitle === "node"
		const shouldOnlyReleaseOnExit =
			windowTitle === "OpenCode" && automaticRename === "0"

		if (shouldRenameToOpenCode || shouldOnlyReleaseOnExit) {
			targetWindow = windowID || undefined
			releaseTitleOnExit = true
			if (targetWindow) {
				scheduleWindowTitleRelease(targetWindow)
			}
			process.once("beforeExit", releaseWindowTitle)
			process.once("exit", releaseWindowTitle)
			process.once("SIGINT", () => {
				releaseWindowTitle()
				process.exit(130)
			})
			process.once("SIGTERM", () => {
				releaseWindowTitle()
				process.exit(143)
			})
			if (shouldRenameToOpenCode) {
				const setAutomaticRenameOffArgs = targetWindow
					? ["set-window-option", "-t", targetWindow, "automatic-rename", "off"]
					: ["set-window-option", "automatic-rename", "off"]
				const renameWindowArgs = targetWindow
					? ["rename-window", "-t", targetWindow, "OpenCode"]
					: ["rename-window", "OpenCode"]
				execFileSync("tmux", setAutomaticRenameOffArgs, { stdio: "ignore" })
				execFileSync("tmux", renameWindowArgs, { stdio: "ignore" })
			}
		}
	} catch {}

	return {}
}
