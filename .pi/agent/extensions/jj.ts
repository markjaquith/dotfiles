import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

function getJjSystemInstruction(root: string): string {
	return `## Version control

This repository is jj-enabled (workspace root: \`${root}\`). Prefer \`jj\` over \`git\` for all version control commands. Use \`git\` only when explicitly requested or when no suitable \`jj\` command exists.`
}

export default function (pi: ExtensionAPI) {
	const roots = new Map<string, string | null>()

	pi.on("before_agent_start", async (event, ctx) => {
		let root = roots.get(ctx.cwd)
		if (root === undefined) {
			try {
				const result = await pi.exec("jj", ["root"], {
					cwd: ctx.cwd,
					timeout: 5_000,
				})
				root = result.code === 0 ? result.stdout.trim() || null : null
			} catch {
				root = null
			}
			roots.set(ctx.cwd, root)
		}

		if (!root) return
		return {
			systemPrompt: `${event.systemPrompt}\n\n${getJjSystemInstruction(root)}`,
		}
	})
}
