// Worktrunk activity tracking plugin for OpenCode.
//
// Tracks OpenCode session activity per branch, showing status markers in `wt list`:
//   🤖 — agent is working
//   💬 — agent is waiting for input
//
// Installed globally via: wt config plugins opencode install
// Or manually: copy to ~/.config/opencode/plugins/worktrunk.ts

import type { Plugin, PluginModule } from "@opencode-ai/plugin/v1"

export const WorktrunkPlugin: Plugin = async ({ $ }) => {
	return {
		event: async ({ event }) => {
			switch (event.type) {
				case "session.status":
					await $`wt config state marker set ${"🤖"} || true`.quiet()
					break
				case "session.idle":
					await $`wt config state marker set ${"💬"} || true`.quiet()
					break
				case "session.deleted":
					await $`wt config state marker clear || true`.quiet()
					break
			}
		},
	}
}

export default {
	id: "worktrunk",
	server: WorktrunkPlugin,
} satisfies PluginModule
