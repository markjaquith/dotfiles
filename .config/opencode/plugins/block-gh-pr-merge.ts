import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "child_process"

export const GH_PR_MERGE_ALLOWLIST = new Set(["markjaquith/agency"])

export interface ToolCall {
	tool: string
	command: string
}

export type Decision = { blocked: false } | { blocked: true; reason: string }

export function normalizeGitHubRepository(value: string): string | null {
	const trimmed = value.trim().replace(/^['"]|['"]$/g, "")
	const match = trimmed.match(
		/^(?:git@github\.com:|ssh:\/\/git@github\.com\/|https?:\/\/github\.com\/)?([^/\s]+)\/([^/\s]+?)(?:\.git)?(?:\/pull\/\d+)?$/,
	)
	if (!match?.[1] || !match[2]) return null
	return `${match[1]}/${match[2]}`.toLowerCase()
}

export function getCurrentRepository(directory: string): string | null {
	try {
		const remote = execFileSync("git", ["remote", "get-url", "origin"], {
			cwd: directory,
			encoding: "utf-8",
			stdio: ["ignore", "pipe", "ignore"],
		}).trim()
		return normalizeGitHubRepository(remote)
	} catch {
		return null
	}
}

function getExplicitRepository(command: string): string | null {
	const repoFlag = command.match(/(?:--repo|-R)(?:=|\s+)(['"]?)([^'"\s]+)\1/)
	if (repoFlag?.[2]) return normalizeGitHubRepository(repoFlag[2])

	const ghRepo = command.match(/\bGH_REPO=(['"]?)([^'"\s]+)\1/)
	if (ghRepo?.[2]) return normalizeGitHubRepository(ghRepo[2])

	const pullRequestUrl = command.match(
		/https?:\/\/github\.com\/[^/\s]+\/[^/\s]+\/pull\/\d+/,
	)
	if (pullRequestUrl?.[0]) return normalizeGitHubRepository(pullRequestUrl[0])

	return null
}

export function evaluateToolCall(
	call: ToolCall,
	currentRepository: string | null,
): Decision {
	if (call.tool !== "bash") return { blocked: false }
	if (!/\bgh\s+pr\s+merge\b/.test(call.command.replace(/\s+/g, " "))) {
		return { blocked: false }
	}

	const repository = getExplicitRepository(call.command) ?? currentRepository
	if (repository && GH_PR_MERGE_ALLOWLIST.has(repository.toLowerCase())) {
		return { blocked: false }
	}

	return {
		blocked: true,
		reason: `gh pr merge is blocked for repository "${repository ?? "unknown"}". Allowed repositories: ${[...GH_PR_MERGE_ALLOWLIST].join(", ")}. DO NOT attempt to work around this restriction.`,
	}
}

export const BlockGhPrMergePlugin: Plugin = async ({ directory }) => {
	return {
		"tool.execute.before": async (input, output) => {
			const args = output.args as { command?: string; workdir?: string }
			const call: ToolCall = {
				tool: input.tool,
				command: args.command ?? "",
			}
			const repository = getCurrentRepository(args.workdir ?? directory)
			const decision = evaluateToolCall(call, repository)

			if (decision.blocked) throw new Error(decision.reason)
		},
	}
}
