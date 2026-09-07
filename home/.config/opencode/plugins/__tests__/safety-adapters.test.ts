import { describe, expect, mock, test } from "bun:test"
import type { Plugin } from "@opencode-ai/plugin"
import { mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import mergePlugin from "../block-gh-pr-merge"
import npmPlugin, { BlockNpm } from "../blockNpm"
import trashPlugin, {
	TrashInsteadOfRmRfPlugin,
} from "../trash-instead-of-rm-rf"

type ToolHook = Plugin.Context["tool"]["hook"]
type BeforeEvent = Exclude<
	Parameters<Parameters<ToolHook>[1]>[0],
	{ status: string }
>

async function setup(plugin: Plugin.Plugin, directory = "/nonexistent") {
	const callbacks: Array<(event: BeforeEvent) => Promise<void> | void> = []
	const hook: ToolHook = async (name, callback) => {
		expect<string>(name).toBe("execute.before")
		callbacks.push(callback as (event: BeforeEvent) => Promise<void> | void)
		return { dispose: async () => {} }
	}
	// Only the setup dependencies used by these adapters are provided.
	await plugin.setup({
		location: { directory },
		tool: { hook },
	} as Plugin.Context)
	return {
		callbacks,
		async execute(tool: string, input: unknown, run = mock(() => {})) {
			const event = {
				tool,
				input,
				sessionID: "session-test",
				agent: "build",
				messageID: "message-test",
				id: "call-test",
			} as BeforeEvent
			for (const callback of callbacks) await callback(event)
			run()
			return event
		},
	}
}

describe("beta safety adapters", () => {
	test("a merge rejection stops execution without changing the command", async () => {
		const adapter = await setup(mergePlugin)
		expect(adapter.callbacks).toHaveLength(1)
		const input = { command: "gh pr merge 123 --repo example/other" }
		const run = mock(() => {})
		await expect(adapter.execute("bash", input, run)).rejects.toThrow(
			'gh pr merge is blocked for repository "example/other"',
		)
		expect(run).not.toHaveBeenCalled()
		expect(input.command).toBe("gh pr merge 123 --repo example/other")
	})

	test.each(["markjaquith/agency", "markjaquith/topo"])(
		"allows explicit merges in %s",
		async (repository) => {
			const adapter = await setup(mergePlugin)
			const run = mock(() => {})
			await adapter.execute(
				"bash",
				{ command: `gh pr merge 123 --repo ${repository}` },
				run,
			)
			expect(run).toHaveBeenCalledTimes(1)
		},
	)

	test("uses location.directory and honors the input workdir override", async () => {
		const directory = mkdtempSync(join(tmpdir(), "merge-adapter-"))
		try {
			for (const args of [
				["init"],
				["remote", "add", "origin", "https://github.com/markjaquith/topo.git"],
			]) {
				expect(
					Bun.spawnSync(["git", ...args], { cwd: directory }).exitCode,
				).toBe(0)
			}
			const adapter = await setup(mergePlugin, directory)
			await adapter.execute("bash", { command: "gh pr merge 123" })
			await expect(
				adapter.execute("bash", {
					command: "gh pr merge 123",
					workdir: join(directory, "missing"),
				}),
			).rejects.toThrow('repository "unknown"')
			const elsewhere = await setup(mergePlugin)
			await elsewhere.execute("bash", {
				command: "gh pr merge 123",
				workdir: directory,
			})
		} finally {
			rmSync(directory, { recursive: true, force: true })
		}
	})

	test("allows unrelated commands and non-bash tools", async () => {
		const adapter = await setup(mergePlugin)
		await adapter.execute("bash", { command: "gh pr view 123" })
		await adapter.execute("read", { command: "gh pr merge 123" })
		await adapter.execute("read", {})
	})

	test.each([
		"rm -rf target",
		"rm -fr target",
		"rm --recursive --force target",
		"rm --force --recursive target",
		"trash target",
	])(
		"rewrites %s by mutating the same input before execution",
		async (command) => {
			expect(trashPlugin).toBe(TrashInsteadOfRmRfPlugin)
			expect(trashPlugin.id).toBe("trash-instead-of-rm-rf")
			const adapter = await setup(trashPlugin)
			expect(adapter.callbacks).toHaveLength(1)
			const input = { command, workdir: "/somewhere", timeout: 1000 }
			const run = mock(() => {
				expect(input.command).toStartWith("safe_trash() {")
				expect(input.command).toEndWith("safe_trash target")
				expect(input.command).toContain('command trash -- "$@"')
				expect(input.command).toContain("Blocked trash with no targets")
				expect(input.command).toContain(
					"Blocked trash target that resolves to the current directory",
				)
			})
			const event = await adapter.execute("bash", input, run)
			expect(event.input).toBe(input)
			expect(input.workdir).toBe("/somewhere")
			expect(input.timeout).toBe(1000)
			expect(run).toHaveBeenCalledTimes(1)
		},
	)

	test("trash leaves unrelated commands and non-bash input unchanged", async () => {
		const adapter = await setup(trashPlugin)
		for (const [tool, command] of [
			["bash", "git status"],
			["bash", "rm file"],
			["read", "rm -rf target"],
		] as const) {
			const input = { command }
			await adapter.execute(tool, input)
			expect(input.command).toBe(command)
		}
		await adapter.execute("read", {})
	})

	test("npm remains a no-op plugin with no registered hooks", async () => {
		expect(npmPlugin).toBe(BlockNpm)
		expect(npmPlugin.id).toBe("block-npm")
		const adapter = await setup(npmPlugin)
		expect(adapter.callbacks).toHaveLength(0)
		const input = { command: "npm install" }
		await adapter.execute("bash", input)
		expect(input.command).toBe("npm install")
	})
})
