import { execFileSync } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

const isTUI = process.argv[2] !== "run"

export const TmuxWindowTitlePlugin: Plugin = async () => {
	if (!isTUI || !process.env.TMUX) {
		return {}
	}

	try {
		const windowTitle = execFileSync("tmux", ["display-message", "-p", "#W"], {
			encoding: "utf8",
		}).trim()

		if (windowTitle === "node") {
			execFileSync("tmux", ["rename-window", "OpenCode"], { stdio: "ignore" })
		}
	} catch {}

	return {}
}
