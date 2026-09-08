import { expect, test } from "bun:test"
import { mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { isAbsolute, join } from "node:path"
import {
	setupConfig,
	setupModel,
	setupProfile,
} from "../bin/agency-herdr-dispatch.ts"

const executable = process.env.OPENCODE2_TEST_EXECUTABLE

type Agent = {
	id: string
	mode: string
	model?: { id: string; providerID: string; variant?: string }
	request: {
		settings: Record<string, unknown>
		body: Record<string, unknown>
	}
}

test.skipIf(!executable)(
	"OpenCode 2 loads the isolated Agency setup profile without changing worker defaults",
	async () => {
		if (!executable || !isAbsolute(executable)) {
			throw new Error("OPENCODE2_TEST_EXECUTABLE must be an absolute path")
		}
		const root = mkdtempSync(join(tmpdir(), "opencode2-profile-"))
		const password = crypto.randomUUID()
		const listener = Bun.serve({
			hostname: "127.0.0.1",
			port: 0,
			fetch: () => new Response(),
		})
		const port = listener.port!
		listener.stop(true)
		const child = Bun.spawn(
			[executable, "serve", "--hostname", "127.0.0.1", "--port", String(port)],
			{
				cwd: root,
				env: {
					PATH: process.env.PATH,
					HOME: root,
					XDG_CONFIG_HOME: join(root, "config"),
					XDG_DATA_HOME: join(root, "data"),
					XDG_STATE_HOME: join(root, "state"),
					XDG_CACHE_HOME: join(root, "cache"),
					OPENCODE_SERVER_PASSWORD: password,
					OPENCODE_CONFIG_CONTENT: JSON.stringify(setupConfig),
				},
				stdout: "ignore",
				stderr: "ignore",
			},
		)
		try {
			const deadline = Date.now() + 20_000
			let agents: Agent[] = []
			// A listening server can still have an empty, initializing registry.
			while (Date.now() < deadline) {
				if (child.exitCode !== null) {
					throw new Error(`OpenCode server exited with ${child.exitCode}`)
				}
				const response = await fetch(`http://127.0.0.1:${port}/api/agent`, {
					headers: {
						Authorization: `Basic ${Buffer.from(`opencode:${password}`).toString("base64")}`,
					},
					signal: AbortSignal.timeout(1000),
				}).catch(() => undefined)
				if (response && response.status !== 503) {
					expect(response.status).toBe(200)
					const body = (await response.json()) as { data: Agent[] }
					expect(Array.isArray(body.data)).toBe(true)
					agents = body.data
					if (agents.some((agent) => agent.id === setupProfile)) break
				}
				await Bun.sleep(100)
			}
			const setup = agents.find((agent) => agent.id === setupProfile)
			expect(setup).toBeDefined()
			expect(setupConfig.default_agent).toBe(setupProfile)
			expect(setup?.mode).toBe("primary")
			const [providerID, id] = setupModel.split("/")
			if (!providerID || !id) throw new Error("Invalid setup model")
			expect(setup?.model).toEqual({ providerID, id, variant: "low" })
			expect(setup?.request.body.reasoningEffort).toBe("low")
			const build = agents.find((agent) => agent.id === "build")
			expect(build).toBeDefined()
			expect(build?.model).toBeUndefined()
			expect(build?.request.settings).toEqual({})
		} finally {
			child.kill()
			const killTimer = setTimeout(() => child.kill("SIGKILL"), 3000)
			await child.exited
			clearTimeout(killTimer)
			rmSync(root, { recursive: true, force: true })
		}
	},
	30_000,
)
