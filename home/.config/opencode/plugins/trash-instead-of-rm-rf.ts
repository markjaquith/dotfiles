import type { Plugin } from "@opencode-ai/plugin"

const trashCommandPattern = /^\s*trash\s+(.+)$/s

function safeTrashCommand(args: string) {
	return `safe_trash() {
	if [ "$#" -eq 0 ]; then
		echo "Blocked trash with no targets" >&2
		exit 1
	fi
	for target do
		if [ -z "$target" ] || { [ -d "$target" ] && [ "$(cd "$target" && pwd -P)" = "$(pwd -P)" ]; }; then
			echo "Blocked trash target that resolves to the current directory" >&2
			exit 1
		fi
	done
	command trash -- "$@"
}
safe_trash ${args}`
}

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

			const trashMatch = command.match(trashCommandPattern)
			if (trashMatch && trashMatch[1]) {
				output.args.command = safeTrashCommand(trashMatch[1].trim())
				return
			}

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
					output.args.command = safeTrashCommand(path)
					return
				}
			}
		},
	}
}
