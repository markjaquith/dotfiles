import type { Plugin } from "@opencode-ai/plugin"

/**
 * Plugin to block gh pr merge commands.
 *
 * This plugin intercepts bash commands that contain "gh pr merge" and throws an error
 * to prevent the LLM from merging PRs directly. Only humans should merge PRs.
 */
export const BlockGhPrMergePlugin: Plugin = async ({ client }) => {
	return {
		"tool.execute.before": async (input, output) => {
			// Only check bash commands
			if (input.tool !== "bash") {
				return
			}

			const command = output.args.command as string

			// Check for gh pr merge commands
			const ghPrMergePattern = /\bgh\s+pr\s+merge\b/

			if (ghPrMergePattern.test(command)) {
				throw new Error(
					"gh pr merge commands are blocked. DO NOT attempt to work around this restriction. Only humans should merge pull requests. Instead, inform the user that the PR is ready to be merged and ask them to merge it manually when they are ready.",
				)
			}
		},
	}
}
