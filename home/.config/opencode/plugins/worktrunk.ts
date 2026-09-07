// Worktrunk activity tracking plugin for OpenCode.
//
// Tracks OpenCode session activity per branch, showing status markers in `wt list`:
//   🤖 — agent is working
//   💬 — agent is waiting for input
//
// Installed globally via: wt config plugins opencode install
// Or manually: copy to ~/.config/opencode/plugins/worktrunk.ts

import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { Plugin } from "@opencode-ai/plugin"

const exec = promisify(execFile)

export const WorktrunkPlugin = Plugin.define({
	id: "worktrunk",
	setup({ event, location }) {
		const controller = new AbortController()
		const { signal } = controller
		const listening = (async () => {
			for await (const item of event.subscribe({ signal })) {
				if (signal.aborted) break
				if (
					item.location &&
					(item.location.directory !== location.directory ||
						item.location.workspaceID !== location.workspaceID)
				)
					continue
				const args =
					item.type === "session.deleted"
						? ["clear"]
						: item.type === "session.status"
							? ["set", item.data.status.type === "idle" ? "💬" : "🤖"]
							: undefined
				if (!args) continue
				// Like the original `|| true`, missing wt or a non-repository is harmless.
				await exec("wt", ["config", "state", "marker", ...args], {
					cwd: location.directory,
					signal,
				}).catch(() => {})
			}
		})().catch((error: unknown) => {
			if (!signal.aborted)
				console.error("[worktrunk] Event stream failed", error)
		})
		return async () => {
			controller.abort()
			await listening
		}
	},
})

export default WorktrunkPlugin
