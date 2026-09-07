import { expect, test } from "bun:test"
import {
	copyFileSync,
	mkdirSync,
	mkdtempSync,
	readFileSync,
	realpathSync,
	rmSync,
	symlinkSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { isAbsolute, join, resolve } from "node:path"

// Opt in with OPENCODE2_TEST_EXECUTABLE=/absolute/path/to/opencode2.
// No prompts, session shell calls, live config, or package installation.
const executable = process.env.OPENCODE2_TEST_EXECUTABLE
const plugins = [
	["block-gh-pr-merge", "block-gh-pr-merge"],
	["trash-instead-of-rm-rf", "trash-instead-of-rm-rf"],
	["blockNpm", "block-npm"],
	["ding", "ding"],
	["keep-going", "keep-going"],
	["worktrunk", "worktrunk"],
] as const

type OpenAPI = {
	openapi: string
	paths: Record<string, Record<string, { operationId?: string }>>
}
type PluginInfo = {
	id?: string
	source: { type: string; path?: string }
	features: { server?: boolean }
	state: { status: string; error?: string }
}

test.skipIf(!executable)(
	"OpenCode 2 auto-discovers isolated migrated plugins in the real host",
	async () => {
		if (!executable || !isAbsolute(executable)) {
			throw new Error("OPENCODE2_TEST_EXECUTABLE must be an absolute path")
		}
		const root = mkdtempSync(join(tmpdir(), "opencode2-plugins-"))
		let child: ReturnType<typeof Bun.spawn> | undefined
		try {
			const config = join(root, "config", "opencode")
			const source = resolve(import.meta.dir, "../home/.config/opencode")
			mkdirSync(join(config, "plugins"), { recursive: true })
			for (const [file] of plugins) {
				copyFileSync(
					join(source, "plugins", `${file}.ts`),
					join(config, "plugins", `${file}.ts`),
				)
			}
			// Resolve existing dependencies up front; never install into either HOME.
			realpathSync(
				join(source, "node_modules", "@opencode-ai/plugin/package.json"),
			)
			symlinkSync(
				realpathSync(join(source, "node_modules")),
				join(config, "node_modules"),
				"dir",
			)
			const password = crypto.randomUUID()
			const listener = Bun.serve({
				hostname: "127.0.0.1",
				port: 0,
				fetch: () => new Response(),
			})
			const port = listener.port!
			listener.stop(true)
			const deadline = Date.now() + 20_000
			child = Bun.spawn(
				[
					executable,
					"serve",
					"--hostname",
					"127.0.0.1",
					"--port",
					String(port),
				],
				{
					cwd: root,
					// Explicit whitelist: no credentials, Herdr metadata, overlays, or wt.
					env: {
						PATH: "/usr/bin:/bin",
						HOME: root,
						TMPDIR: root,
						XDG_CONFIG_HOME: join(root, "config"),
						XDG_DATA_HOME: join(root, "data"),
						XDG_STATE_HOME: join(root, "state"),
						XDG_CACHE_HOME: join(root, "cache"),
						OPENCODE_SERVER_PASSWORD: password,
						OPENCODE_DING: "0",
						OPENCODE_DISABLE_DEFAULT_PLUGINS: "1",
						OPENCODE_CONFIG_CONTENT: JSON.stringify({
							enabled_providers: [],
							snapshot: false,
							autoupdate: false,
						}),
					},
					stdout: Bun.file(join(root, "stdout.log")),
					stderr: Bun.file(join(root, "stderr.log")),
				},
			)
			const request = (path: string, method = "GET", authenticated = true) => {
				if (Date.now() >= deadline)
					throw new Error("Host smoke test deadline exceeded")
				if (child?.exitCode !== null)
					throw new Error(`OpenCode exited with ${child?.exitCode}`)
				return fetch(`http://127.0.0.1:${port}${path}`, {
					method,
					headers: authenticated
						? {
								Authorization: `Basic ${Buffer.from(`opencode:${password}`).toString("base64")}`,
							}
						: {},
					redirect: "error",
					signal: AbortSignal.timeout(Math.min(5000, deadline - Date.now())),
				})
			}
			let document: OpenAPI | undefined
			while (Date.now() < deadline && !document) {
				// Bootstrap URL observed on beta19228; API operation paths come from it.
				const response = await request("/openapi.json").catch(() => undefined)
				if (response?.ok) {
					const body = (await response.json()) as OpenAPI
					expect(body.openapi).toBeString()
					expect(body.paths).toBeObject()
					document = body
				} else {
					await response?.body?.cancel()
					await Bun.sleep(100)
				}
			}
			if (!document)
				throw new Error("Host did not publish /openapi.json before deadline")
			const operations = Object.entries(document.paths).flatMap(
				([path, methods]) =>
					Object.entries(methods).map(([method, operation]) => ({
						path,
						method: method.toUpperCase(),
						id: operation.operationId,
					})),
			)
			const commands = operations.find((op) => op.id === "v2.command.list")
			expect(commands).toBeDefined()
			expect(commands!.method).toBe("GET")
			const unauthorized = await request(commands!.path, "GET", false)
			expect(unauthorized.status).toBe(401)
			await unauthorized.body?.cancel()

			const activation = operations.find(
				(op) => op.id === "v2.plugin.awaitActivation",
			)
			if (activation) {
				expect(activation.method).toBe("POST")
				const response = await request(activation.path, activation.method)
				expect(response.status).toBe(204)
			}
			const status = operations.find((op) => op.id === "v2.plugin.list")
			if (status) {
				expect(status.method).toBe("GET")
				let loaded: PluginInfo[] = []
				// Listening (and even an initial 200) can precede registry activation.
				while (Date.now() < deadline) {
					const response = await request(status.path)
					expect(response.status).toBe(200)
					const body = (await response.json()) as { data: PluginInfo[] }
					expect(Array.isArray(body.data)).toBe(true)
					loaded = body.data
					expect(
						loaded.filter((plugin) => plugin.state.status === "failed"),
					).toEqual([])
					if (
						plugins.every(([, id]) => loaded.some((plugin) => plugin.id === id))
					)
						break
					await Bun.sleep(100)
				}
				const local = loaded.filter((plugin) => plugin.source.type === "local")
				expect(local.map((plugin) => plugin.id).sort()).toEqual(
					plugins.map(([, id]) => id).sort(),
				)
				for (const [file, id] of plugins) {
					const plugin = local.find((item) => item.id === id)!
					expect(plugin.state).toEqual({ status: "active" })
					expect(plugin.features.server).toBe(true)
					expect(realpathSync(plugin.source.path!)).toBe(
						realpathSync(join(config, "plugins", `${file}.ts`)),
					)
				}
				console.info(
					`[host smoke] ${status.method} ${status.path}: all six local plugins active`,
				)
			} else {
				console.warn(
					"[host smoke GAP] No plugin status API; all-six activation unverified",
				)
			}
			let registered: { name: string; description?: string }[] = []
			while (Date.now() < deadline) {
				const response = await request(commands!.path)
				expect(response.status).toBe(200)
				const body = (await response.json()) as { data: typeof registered }
				expect(Array.isArray(body.data)).toBe(true)
				registered = body.data
				if (registered.some((command) => command.name === "keep-going")) break
				await Bun.sleep(100)
			}
			expect(
				registered.filter((command) => command.name === "keep-going"),
			).toEqual([
				{ name: "keep-going", description: "Keep going until truly done" },
			])
			console.info(
				`[host smoke] GET ${commands!.path}: keep-going registered (not invoked)`,
			)

			// beta19228 has no tool API. Never substitute session.shell or prompts,
			// or call imported hook callbacks and describe that as host execution.
			const toolAPI = operations.filter((op) =>
				/tool|execute/i.test(`${op.path} ${op.id ?? ""}`),
			)
			expect(
				toolAPI,
				"Host now advertises tool/execute operations: inspect their runtime schemas and add a non-shell fixture before exercising hooks",
			).toEqual([])
			console.warn(
				"[host smoke GAP] /openapi.json advertises no tool list/execute endpoint. Merge blocking and trash input rewriting are NOT host-verified; no mock tool was executed. block-npm is currently a no-op.",
			)
		} catch (error) {
			if (child) {
				for (const file of ["stdout.log", "stderr.log"]) {
					console.error(
						`[host smoke ${file}]\n${readFileSync(join(root, file), "utf8").slice(-16_000)}`,
					)
				}
			}
			throw error
		} finally {
			if (child) {
				child.kill()
				const killTimer = setTimeout(() => child?.kill("SIGKILL"), 3000)
				try {
					await child.exited
				} finally {
					clearTimeout(killTimer)
					rmSync(root, { recursive: true, force: true })
				}
			} else {
				rmSync(root, { recursive: true, force: true })
			}
		}
	},
	30_000,
)
