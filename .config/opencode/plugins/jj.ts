import type { Plugin, PluginModule } from "@opencode-ai/plugin"
import { execFileSync } from "child_process"

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

This repository is jj-enabled (workspace root: \`${root}\`). Prefer \`jj\` over \`git\` for all version control commands. Use \`git\` only when explicitly requested or when no suitable \`jj\` command exists.`
}

export const JjPlugin: Plugin = async ({ directory }) => {
	const root = getJjRoot(directory)

	return {
		"experimental.chat.system.transform": async (_input, output) => {
			if (!root) return
			output.system.push(getJjSystemInstruction(root))
		},
	}
}

export default {
	id: "jj",
	server: JjPlugin,
} satisfies PluginModule
