import type { Plugin } from "@opencode-ai/plugin"

export const Ding: Plugin = async ({ $ }) => {
	return {
		async event(input) {
			if (input.event.type === "session.idle") {
				await $`afplay /System/Library/Sounds/Glass.aiff`
			}
		},
	}
}
