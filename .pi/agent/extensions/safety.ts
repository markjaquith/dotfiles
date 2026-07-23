import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { isToolCallEventType } from "@earendil-works/pi-coding-agent"

const GH_PR_MERGE_ALLOWLIST = new Set(["markjaquith/agency"])

const destructiveRmPatterns = [
	/^\s*rm\s+-[a-zA-Z]*r[a-zA-Z]*f\s+(.+)$/s,
	/^\s*rm\s+-[a-zA-Z]*f[a-zA-Z]*r\s+(.+)$/s,
	/^\s*rm\s+--recursive\s+--force\s+(.+)$/s,
	/^\s*rm\s+--force\s+--recursive\s+(.+)$/s,
]

const destructiveRmAnywherePatterns = [
	/\brm\s+-[a-zA-Z]*r[a-zA-Z]*f\s+/,
	/\brm\s+-[a-zA-Z]*f[a-zA-Z]*r\s+/,
	/\brm\s+--recursive\s+--force\s+/,
	/\brm\s+--force\s+--recursive\s+/,
]

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

function containsShellControl(value: string) {
	return /(?:&&|\|\||[;|\n])/.test(value)
}

function rewriteDestructiveRm(command: string) {
	const trashMatch = command.match(/^\s*trash\s+(.+)$/s)
	if (trashMatch?.[1] && !containsShellControl(trashMatch[1])) {
		return safeTrashCommand(trashMatch[1].trim())
	}

	for (const pattern of destructiveRmPatterns) {
		const match = command.match(pattern)
		if (!match?.[1] || containsShellControl(match[1])) continue

		const targets = match[1].trim().replace(/^--\s+/, "")
		return safeTrashCommand(targets)
	}

	return undefined
}

function containsDestructiveRm(command: string) {
	return destructiveRmAnywherePatterns.some((pattern) => pattern.test(command))
}

function normalizeGitHubRepository(value: string) {
	const trimmed = value.trim().replace(/^['"]|['"]$/g, "")
	const match = trimmed.match(
		/^(?:git@github\.com:|ssh:\/\/git@github\.com\/|https?:\/\/github\.com\/)?([^/\s]+)\/([^/\s]+?)(?:\.git)?(?:\/pull\/\d+)?$/,
	)
	if (!match?.[1] || !match[2]) return null
	return `${match[1]}/${match[2]}`.toLowerCase()
}

function getExplicitRepository(command: string) {
	const repoFlag = command.match(/(?:--repo|-R)(?:=|\s+)(['"]?)([^'"\s]+)\1/)
	if (repoFlag?.[2]) return normalizeGitHubRepository(repoFlag[2])

	const ghRepo = command.match(/\bGH_REPO=(['"]?)([^'"\s]+)\1/)
	if (ghRepo?.[2]) return normalizeGitHubRepository(ghRepo[2])

	const pullRequestUrl = command.match(
		/https?:\/\/github\.com\/[^/\s]+\/[^/\s]+\/pull\/\d+/,
	)
	if (pullRequestUrl?.[0]) {
		return normalizeGitHubRepository(pullRequestUrl[0])
	}

	return null
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return

		const command = event.input.command
		const rewritten = rewriteDestructiveRm(command)
		if (rewritten) {
			event.input.command = rewritten
			return
		}

		if (containsDestructiveRm(command)) {
			pi.events.emit("pi:attention", {
				label: "Blocked compound rm command",
			})
			return {
				block: true,
				reason:
					"Compound commands containing rm -rf are blocked. Split the command and use trash for the destructive step.",
			}
		}

		if (!/\bgh\s+pr\s+merge\b/.test(command.replace(/\s+/g, " "))) {
			return
		}

		let repository = getExplicitRepository(command)
		if (!repository) {
			const remote = await pi.exec("git", ["remote", "get-url", "origin"], {
				cwd: ctx.cwd,
				timeout: 5_000,
			})
			if (remote.code === 0) {
				repository = normalizeGitHubRepository(remote.stdout)
			}
		}

		if (repository && GH_PR_MERGE_ALLOWLIST.has(repository)) return

		pi.events.emit("pi:attention", { label: "Blocked gh pr merge" })
		return {
			block: true,
			reason: `gh pr merge is blocked for repository "${repository ?? "unknown"}". Allowed repositories: ${[...GH_PR_MERGE_ALLOWLIST].join(", ")}. Do not attempt to work around this restriction.`,
		}
	})
}
