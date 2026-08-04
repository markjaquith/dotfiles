import type { Plugin, PluginModule } from "@opencode-ai/plugin"
import { execFileSync } from "child_process"

const rawGitCommandPattern =
	/(?:^|&&|\|\||[;|\n(])\s*(?:[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|"[^"]*"|[^\s]+)\s+)*(?:(?:command|env|sudo)(?:\s+-\S+)*\s+)*(?:[^\s;&|()]*\/)?git(?=\s|$)/

export type JjCommandDecision =
	| { blocked: false }
	| { blocked: true; reason: string }

export function getJjRoot(directory: string): string | null {
	try {
		return execFileSync("jj", ["root"], {
			cwd: directory,
			encoding: "utf-8",
			stdio: ["ignore", "pipe", "ignore"],
		}).trim()
	} catch {
		return null
	}
}

export function getJjSystemInstruction(root: string): string {
	return `## Version control

This repository is jj-enabled (workspace root: \`${root}\`). Use \`jj\` for all version control commands. Raw \`git\` commands through the bash tool are blocked. Use alternatives such as \`jj status\`, \`jj diff\`, \`jj log\`, \`jj show\`, \`jj commit\`, \`jj bookmark\`, \`jj rebase\`, \`jj git fetch\`, and \`jj git push\`.`
}

export function evaluateBashCommand(
	command: string,
	root: string | null,
): JjCommandDecision {
	if (!root || !rawGitCommandPattern.test(command)) return { blocked: false }

	return {
		blocked: true,
		reason:
			"Raw git commands are blocked in jj repositories. Use the jj equivalent instead, such as `jj status`, `jj diff`, `jj log`, `jj show`, `jj commit`, `jj bookmark`, `jj rebase`, `jj git fetch`, or `jj git push`.",
	}
}

export const JjPlugin: Plugin = async ({ directory }) => {
	const root = getJjRoot(directory)
	return {}

	return {
		"experimental.chat.system.transform": async (_input, output) => {
			if (!root) return
			output.system.push(getJjSystemInstruction(root))
		},
		"tool.execute.before": async (input, output) => {
			if (input.tool !== "bash") return

			const args = output.args as { command?: string }
			const decision = evaluateBashCommand(args.command ?? "", root)
			if (decision.blocked) throw new Error(decision.reason)
		},
	}
}

export default {
	id: "jj",
	server: JjPlugin,
} satisfies PluginModule
