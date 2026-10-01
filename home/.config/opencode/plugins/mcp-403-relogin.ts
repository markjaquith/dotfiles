// Re-authenticates remote MCP servers that get stuck on an HTTP 403.
//
// OpenCode only refreshes OAuth tokens after a 401. When an edge proxy answers
// an expired token with a 403 instead, the server stays "failed" until you run
// `opencode mcp logout <name> && opencode mcp auth <name>`. This plugin runs
// that for you (which may open a browser), then reconnects.

import { execFile } from "node:child_process"
import { open, rm, stat } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { promisify } from "node:util"
import { Plugin } from "@opencode-ai/plugin"

const exec = promisify(execFile)

const SERVERS = new Set(["runlayer-plugin"])
const FORBIDDEN_RE = /\b403\b/
const COOLDOWN_MS = 10 * 60 * 1000
const AUTH_TIMEOUT_MS = 5 * 60 * 1000

type McpEntry = { name: string; status: { status: string; error?: string } }

const inFlight = new Map<string, Promise<boolean>>()

function log(message: string) {
	console.error(`[mcp-403-relogin] ${message}`)
}

// One relogin per server per cooldown window across every OpenCode process.
// The lock file is kept afterwards; its mtime marks the start of the cooldown.
async function acquireLock(server: string): Promise<boolean> {
	const path = join(tmpdir(), `opencode-mcp-403-relogin-${server}.lock`)
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

async function relogin(server: string): Promise<boolean> {
	if (!(await acquireLock(server))) return false
	log(`"${server}" is failing with 403; re-authenticating (check your browser)`)
	try {
		await exec(process.execPath, ["mcp", "logout", server])
		await exec(process.execPath, ["mcp", "auth", server], {
			timeout: AUTH_TIMEOUT_MS,
		})
		log(`"${server}" re-authenticated`)
		return true
	} catch (error) {
		log(`re-authenticating "${server}" failed: ${String(error)}`)
		return false
	}
}

function reloginOnce(server: string): Promise<boolean> {
	const existing = inFlight.get(server)
	if (existing) return existing
	const attempt = relogin(server).finally(() => inFlight.delete(server))
	inFlight.set(server, attempt)
	return attempt
}

function isStuckOn403(entry: McpEntry | undefined): boolean {
	if (entry?.status.status !== "failed") return false
	return FORBIDDEN_RE.test(entry.status.error ?? "")
}

export const Mcp403ReloginPlugin = Plugin.define({
	id: "mcp-403-relogin",
	setup({ event, location, mcp }) {
		const controller = new AbortController()
		const { signal } = controller
		const listening = (async () => {
			for await (const item of event.subscribe({ signal })) {
				if (signal.aborted) break
				if (item.type !== "mcp.status.changed") continue
				const server = item.data.server
				if (!SERVERS.has(server)) continue
				if (
					item.location &&
					(item.location.directory !== location.directory ||
						item.location.workspaceID !== location.workspaceID)
				)
					continue

				const { data } = await mcp.list()
				if (!isStuckOn403(data.find((entry) => entry.name === server))) continue
				if (await reloginOnce(server)) await mcp.reload()
			}
		})().catch((error: unknown) => {
			if (!signal.aborted) log(`event stream failed: ${String(error)}`)
		})
		return async () => {
			controller.abort()
			await listening
		}
	},
})

export default Mcp403ReloginPlugin
