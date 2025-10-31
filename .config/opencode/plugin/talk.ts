import type { Plugin } from "@opencode-ai/plugin"

export const Talk: Plugin = async ({ $ }) => {
	return {
		async event(input) {
			if (input.event.type === "session.idle") {
				await $`afplay /System/Library/Sounds/Glass.aiff`
			}
		},
	}
}
