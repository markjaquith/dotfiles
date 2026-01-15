import type { Plugin } from "@opencode-ai/plugin"

/**
 * Plugin to block git push commands.
 *
 * This plugin intercepts bash commands that contain "git push" and throws an error
 * to prevent the LLM from pushing directly. The LLM should inform the user to push manually.
 */
export const BlockGitPushPlugin: Plugin = async ({ client }) => {
	return {
		"tool.execute.before": async (input, output) => {
			// Only check bash commands
			if (input.tool !== "bash") {
				return
			}

			const command = output.args.command as string

			// Check for git push commands
			const gitPushPattern = /^\bgit\s+push\b/

			if (gitPushPattern.test(command)) {
				throw new Error(
					"Git push commands are blocked. DO NOT attempt to work around this restriction. Instead, when you are done working, inform the user that you have completed the requested work and ask them to run 'git push' manually to push the changes to the remote repository.",
				)
			}
		},
	}
}
