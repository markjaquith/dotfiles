import { expect, test } from "bun:test"
import net from "node:net"
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import serverPlugin from "../home/.config/opencode/plugins/herdr-agent-state.js"
import tuiPlugin from "../home/.config/opencode/herdr-opencode/tui.js"

test("Herdr native V1/V2 entrypoints preserve pane-local completion reporting", async () => {
	const directory = await mkdtemp(join(tmpdir(), "herdr-native-"))
	const socket = join(directory, "s")
	const previous = { ...process.env }
	const reports: { params: { state?: string; agent_session_id?: string } }[] =
		[]
	const server = net.createServer((client) => {
		client.once("data", (data) => {
			reports.push(JSON.parse(data.toString()))
			client.end("{}\n")
		})
	})
	await new Promise<void>((resolve) => server.listen(socket, resolve))
	Object.assign(process.env, {
		HERDR_ENV: "1",
		HERDR_PANE_ID: "test-pane",
		HERDR_SOCKET_PATH: socket,
	})
	type Event = { details: { type: string; data: { sessionID: string } } }
	const listeners = new Set<(event: Event) => void>()
	let cleanup: (() => void) | undefined
	try {
		expect(serverPlugin.server).toBeFunction()
		expect(tuiPlugin.tui).toBeFunction()
		await serverPlugin.setup()
		expect(reports).toEqual([])
		cleanup = tuiPlugin.setup({
			ui: {
				router: { current: () => ({ type: "session", sessionID: "root" }) },
			},
			data: {
				listen(handler: (event: Event) => void) {
					listeners.add(handler)
					return () => listeners.delete(handler)
				},
				session: {
					get: (id: string) => ({ id }),
					family: () => [],
					status: () => "idle",
					permission: { list: () => [] },
					form: { list: () => [] },
				},
			},
		})
		await Bun.sleep(40)
		reports.length = 0
		for (const type of [
			"session.execution.started",
			"session.execution.succeeded",
		]) {
			for (const listener of listeners) {
				listener({ details: { type, data: { sessionID: "root" } } })
			}
		}
		await Bun.sleep(40)
		expect(reports.map((report) => report.params.state)).toEqual([
			"working",
			"idle",
		])
		expect(
			reports.every((report) => report.params.agent_session_id === "root"),
		).toBe(true)
		cleanup?.()
		expect(listeners.size).toBe(0)
	} finally {
		cleanup?.()
		for (const key of ["HERDR_ENV", "HERDR_PANE_ID", "HERDR_SOCKET_PATH"]) {
			if (previous[key] === undefined) delete process.env[key]
			else process.env[key] = previous[key]
		}
		await new Promise<void>((resolve) => server.close(() => resolve()))
		await rm(directory, { recursive: true })
	}
})

test("OpenCode installer accepts native Herdr and rejects legacy reporters", async () => {
	const root = await mkdtemp(join(tmpdir(), "herdr-install-"))
	try {
		const bin = join(root, "bin")
		const plugins = join(root, "home/.config/opencode/plugins")
		await mkdir(bin, { recursive: true })
		await mkdir(plugins, { recursive: true })
		const installer = join(bin, "dotfiles-install-opencode.zsh")
		await writeFile(
			installer,
			await readFile(
				new URL("../bin/dotfiles-install-opencode.zsh", import.meta.url),
			),
		)
		await writeFile(join(bin, "npm"), '#!/bin/sh\nprintf "stub npm ci\\n"\n', {
			mode: 0o755,
		})
		await writeFile(
			join(bin, "bun"),
			'#!/bin/sh\nif [ "$1" = "pm" ]; then printf "%s\\n" "$STUB_GLOBAL_BIN"; fi\n',
			{ mode: 0o755 },
		)
		await writeFile(
			join(bin, "opencode2"),
			'#!/bin/sh\nprintf "stub OpenCode2\\n"\n',
			{ mode: 0o755 },
		)
		for (const version of ["11", "12"]) {
			await writeFile(
				join(plugins, "herdr-agent-state.js"),
				`// HERDR_INTEGRATION_VERSION=${version}\n`,
			)
			const child = Bun.spawn(["/bin/zsh", installer], {
				env: { PATH: `${bin}:/usr/bin:/bin`, HOME: root, STUB_GLOBAL_BIN: bin },
				stdout: "pipe",
				stderr: "pipe",
			})
			const [code, stdout, stderr] = await Promise.all([
				child.exited,
				new Response(child.stdout).text(),
				new Response(child.stderr).text(),
			])
			expect(code).toBe(version === "12" ? 0 : 1)
			if (version === "12") expect(stdout).toContain("stub OpenCode2")
			else {
				expect(stdout).not.toContain("stub npm ci")
				expect(stderr).toContain("version 12 or newer")
			}
		}
	} finally {
		await rm(root, { recursive: true })
	}
})
