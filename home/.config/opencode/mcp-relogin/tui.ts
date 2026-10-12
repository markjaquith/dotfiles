// Re-authenticates remote MCP servers that need a new OAuth login.
//
// This runs in the TUI rather than the background service: the service has no
// terminal (its output goes to /dev/null), so it can neither tell you what it is
// doing nor reliably hand you a browser window. When a watched server reports
// `needs_auth`, or is stuck on an HTTP 403 that OpenCode will not refresh on its
// own, this drops the stale credential, starts the OAuth flow, opens the
// browser, and reconnects once you have signed in.

import { execFile } from "node:child_process"
import { open, rm, stat } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import type { McpServer } from "@opencode/client"
import type { Context } from "@opencode/plugin/tui/context"

const SERVERS = new Set(["runlayer-plugin"])
const FORBIDDEN_RE = /\b403\b/
const COOLDOWN_MS = 10 * 60 * 1000
const POLL_MS = 2000

type Reason = "needs_auth" | "forbidden"

function sleep(ms: number) {
	return new Promise((resolve) => setTimeout(resolve, ms))
}

function openBrowser(url: string) {
	const command = process.platform === "darwin" ? "open" : "xdg-open"
	execFile(command, [url], () => {})
}

function reloginReason(entry: McpServer | undefined): Reason | undefined {
	if (!entry) return undefined
	if (entry.status.status === "needs_auth") return "needs_auth"
	if (entry.status.status === "failed" && FORBIDDEN_RE.test(entry.status.error))
		return "forbidden"
	return undefined
}

// One login prompt per server per cooldown window across every OpenCode TUI.
// The lock file is kept afterwards; its mtime marks the start of the cooldown.
async function acquireLock(server: string): Promise<boolean> {
	const path = join(tmpdir(), `opencode-mcp-relogin-${server}.lock`)
	const lastStarted = await stat(path).then(
		(info) => info.mtimeMs,
		() => undefined,
	)
	if (lastStarted !== undefined) {
		if (Date.now() - lastStarted < COOLDOWN_MS) return false
		await rm(path, { force: true })
	}
	try {
		const handle = await open(path, "wx")
		await handle.close()
		return true
	} catch {
		return false
	}
}

export default {
	id: "mcp-relogin",
	setup(context: Context) {
		const { client, ui } = context
		const location = context.location ?? context.data.location.default()
		const inFlight = new Map<string, Promise<void>>()
		const triedConnect = new Set<string>()
		let disposed = false

		const toast = (
			message: string,
			variant: "info" | "success" | "error" = "info",
		) => ui.toast.show({ title: "MCP login", message, variant })

		async function find(server: string) {
			const { data } = await client.mcp.list({ location })
			return data.find((entry) => entry.name === server)
		}

		async function login(server: string, integrationID: string) {
			const integration = await client.integration.get({
				integrationID,
				location,
			})
			const method = integration.data?.methods.find(
				(item) => item.type === "oauth",
			)
			if (!method) {
				toast(`"${server}" has no OAuth sign-in method`, "error")
				return false
			}

			const attempt = await client.integration.oauth.connect({
				integrationID,
				methodID: method.id,
				location,
			})
			const { attemptID, url, mode } = attempt.data
			openBrowser(url)
			toast(`Sign in to "${server}" in your browser`)

			if (mode === "code") {
				const code = await ui.dialog.prompt({
					title: `Sign in to ${server}`,
					placeholder: "Paste the authorization code",
				})
				if (!code) {
					await client.integration.oauth.cancel({
						integrationID,
						attemptID,
						location,
					})
					return false
				}
				await client.integration.oauth.complete({
					integrationID,
					attemptID,
					code,
					location,
				})
				return true
			}

			while (!disposed) {
				await sleep(POLL_MS)
				const { data } = await client.integration.oauth.status({
					integrationID,
					attemptID,
					location,
				})
				if (data.status === "complete") return true
				if (data.status === "failed") {
					toast(`Signing in to "${server}" failed: ${data.message}`, "error")
					return false
				}
				if (data.status === "expired") {
					toast(`Sign-in to "${server}" expired`, "error")
					return false
				}
			}
			return false
		}

		async function credentialsFor(integrationID: string) {
			const integration = await client.integration.get({
				integrationID,
				location,
			})
			return (integration.data?.connections ?? []).filter(
				(connection) => connection.type === "credential",
			)
		}

		async function relogin(server: string) {
			const entry = await find(server)
			if (!reloginReason(entry) || !entry?.integrationID) return
			const { integrationID } = entry

			// Another TUI may already have signed in. Try its credential once per
			// credential change before deciding it is stale; retrying on every
			// status change would loop.
			if (
				!triedConnect.has(server) &&
				(await credentialsFor(integrationID)).length > 0
			) {
				triedConnect.add(server)
				await client.mcp.connect({ server, location })
				if (!reloginReason(await find(server))) return
			}

			if (!(await acquireLock(server))) return

			for (const credential of await credentialsFor(integrationID))
				await client.credential.remove({
					credentialID: credential.id,
				})

			if (!(await login(server, integrationID))) return
			await client.mcp.connect({ server, location })
			toast(`"${server}" re-authenticated`, "success")
		}

		function check(server: string) {
			if (disposed || inFlight.has(server)) return
			const attempt = relogin(server)
				.catch((error: unknown) =>
					toast(
						`Re-authenticating "${server}" failed: ${String(error)}`,
						"error",
					),
				)
				.finally(() => inFlight.delete(server))
			inFlight.set(server, attempt)
		}

		const checkAll = () => SERVERS.forEach(check)
		const onCredentialChange = () => {
			triedConnect.clear()
			checkAll()
		}

		const stops = [
			context.data.on("mcp.status.changed", (event) => {
				if (SERVERS.has(event.data.server)) check(event.data.server)
			}),
			context.data.on("credential.updated", onCredentialChange),
			context.data.on("credential.switched", onCredentialChange),
		]

		// Status changes that settled before this TUI started emit no event.
		checkAll()

		return () => {
			disposed = true
			stops.forEach((stop) => stop())
		}
	},
}
