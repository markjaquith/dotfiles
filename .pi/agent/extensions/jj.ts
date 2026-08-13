import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { isToolCallEventType } from "@earendil-works/pi-coding-agent"
import { rewriteGhCommands } from "../../../.config/opencode/plugins/lib/jj-shell"

const rawGitCommandPattern =
	/(?:^|&&|\|\||[;|\n(])\s*(?:[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|"[^"]*"|[^\s]+)\s+)*(?:(?:command|env|sudo)(?:\s+-\S+)*\s+)*(?:[^\s;&|()]*\/)?git(?=\s|$)/

function containsRawGitCommand(command: string): boolean {
	return rawGitCommandPattern.test(command)
}

const rawGitBlockReason =
	"Raw git commands are blocked in jj repositories. Use the jj equivalent instead, such as `jj status`, `jj diff`, `jj log`, `jj show`, `jj commit`, `jj bookmark`, `jj rebase`, `jj git fetch`, or `jj git push`."

export type JjCommandDecision =
	| { blocked: false }
	| { blocked: true; reason: string }

export function getJjSystemInstruction(root: string): string {
	return `## Version control

This repository is jj-enabled (workspace root: \`${root}\`). Use \`jj\` for all version control commands. Raw \`git\` commands through the bash tool are blocked. Use alternatives such as \`jj status\`, \`jj diff\`, \`jj log\`, \`jj show\`, \`jj commit\`, \`jj bookmark\`, \`jj rebase\`, \`jj git fetch\`, and \`jj git push\`.`
}

export function evaluateBashCommand(
	command: string,
	root: string | null,
): JjCommandDecision {
	const commandForGitCheck = command.replace(
		/\$\(\s*jj\s+git\s+root(?:\s+--ignore-working-copy)?\s*\)/g,
		"JJ_GIT_ROOT",
	)
	if (!root || !containsRawGitCommand(commandForGitCheck)) {
		return { blocked: false }
	}

	return { blocked: true, reason: rawGitBlockReason }
}

export function rewriteBashCommand(
	command: string,
	root: string | null,
): string {
	return root ? rewriteGhCommands(command) : command
}

async function getJjRoot(
	pi: ExtensionAPI,
	roots: Map<string, string | null>,
	directory: string,
): Promise<string | null> {
	const cached = roots.get(directory)
	if (cached !== undefined) return cached

	let root: string | null
	try {
		const result = await pi.exec("jj", ["root"], {
			cwd: directory,
			timeout: 5_000,
		})
		root = result.code === 0 ? result.stdout.trim() || null : null
	} catch {
		root = null
	}

	roots.set(directory, root)
	return root
}

export default function (pi: ExtensionAPI) {
	const roots = new Map<string, string | null>()

	pi.on("before_agent_start", async (event, ctx) => {
		const root = await getJjRoot(pi, roots, ctx.cwd)
		if (!root) return
		return {
			systemPrompt: `${event.systemPrompt}\n\n${getJjSystemInstruction(root)}`,
		}
	})

	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return

		const root = await getJjRoot(pi, roots, ctx.cwd)
		const decision = evaluateBashCommand(event.input.command, root)
		if (decision.blocked) {
			pi.events.emit("pi:attention", { label: "Blocked raw git command" })
			return { block: true, reason: decision.reason }
		}

		event.input.command = rewriteBashCommand(event.input.command, root)
	})
}
