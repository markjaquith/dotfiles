import type { Plugin } from "@opencode-ai/plugin"

/**
 * Plugin to rewrite dangerous rm -rf commands to use trash CLI instead.
 *
 * This plugin intercepts bash commands that contain "rm -rf" patterns and rewrites them
 * to use the safer `trash` CLI tool instead.
 */
export const TrashInsteadOfRmRfPlugin: Plugin = async ({ client }) => {
	return {
		"tool.execute.before": async (input, output) => {
			// Only check bash commands
			if (input.tool !== "bash") {
				return
			}

			const command = output.args.command as string

			// Check for various forms of rm -rf and capture the path
			const dangerousPatterns = [
				{ pattern: /\brm\s+-[a-zA-Z]*r[a-zA-Z]*f\s+(.+)/, desc: "rm -rf" }, // rm -rf <path>
				{ pattern: /\brm\s+-[a-zA-Z]*f[a-zA-Z]*r\s+(.+)/, desc: "rm -fr" }, // rm -fr <path>
				{
					pattern: /\brm\s+--recursive\s+--force\s+(.+)/,
					desc: "rm --recursive --force",
				},
				{
					pattern: /\brm\s+--force\s+--recursive\s+(.+)/,
					desc: "rm --force --recursive",
				},
			]

			for (const { pattern } of dangerousPatterns) {
				const match = command.match(pattern)
				if (match && match[1]) {
					const path = match[1].trim()

					// Rewrite the command to use trash instead
					output.args.command = `trash ${path}`
					return
				}
			}
		},
	}
}
