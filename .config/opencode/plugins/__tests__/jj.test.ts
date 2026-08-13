import { describe, expect, test } from "bun:test"
import { mkdirSync, mkdtempSync, realpathSync, rmSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"
import JjPluginModule, {
	evaluateBashCommand,
	getJjRoot,
	getJjSystemInstruction,
	JjPlugin,
	rewriteBashCommand,
} from "../jj"

describe("jj", () => {
	test("exports an explicit plugin module", () => {
		expect(JjPluginModule.id).toBe("jj")
		expect(JjPluginModule.server).toBe(JjPlugin)
	})

	test("detects a jj workspace from a nested directory", () => {
		const directory = mkdtempSync(join(tmpdir(), "opencode-jj-plugin-"))
		const nested = join(directory, "nested")
		try {
			Bun.spawnSync(["jj", "git", "init", directory])
			mkdirSync(nested)
			expect(getJjRoot(nested)).toBe(realpathSync(directory))
		} finally {
			rmSync(directory, { recursive: true, force: true })
		}
	})

	test("returns null outside a jj workspace", () => {
		const directory = mkdtempSync(join(tmpdir(), "opencode-jj-plugin-"))
		try {
			expect(getJjRoot(directory)).toBeNull()
		} finally {
			rmSync(directory, { recursive: true, force: true })
		}
	})

	test("instructs the model to prefer jj", () => {
		const instruction = getJjSystemInstruction("/workspace/example")
		expect(instruction).toContain("repository is jj-enabled")
		expect(instruction).toContain(
			"Raw `git` commands through the bash tool are blocked",
		)
		expect(instruction).toContain("`jj git push`")
		expect(instruction).toContain("/workspace/example")
	})

	test.each([
		"git status",
		"cd nested && git diff",
		"git log | less",
		"GIT_CONFIG_GLOBAL=/dev/null git status",
		"command git status",
		"/usr/bin/git status",
	])("blocks raw git in a jj workspace: %s", (command) => {
		const decision = evaluateBashCommand(command, "/workspace/example")
		expect(decision.blocked).toBe(true)
		if (decision.blocked) expect(decision.reason).toContain("jj equivalent")
	})

	test.each([
		"jj git fetch",
		"echo git status",
		"gh pr view",
		"GIT_DIR=$(jj git root --ignore-working-copy) gh pr view",
		"git status",
	])(
		"does not block an allowed command or a non-jj workspace: %s",
		(command) => {
			const root = command === "git status" ? null : "/workspace/example"
			expect(evaluateBashCommand(command, root)).toEqual({ blocked: false })
		},
	)

	test("rewrites gh commands in a jj workspace", () => {
		expect(
			rewriteBashCommand("echo ok && gh pr view", "/workspace/example"),
		).toBe(
			"echo ok && GIT_DIR=$(jj git root --ignore-working-copy) gh pr view",
		)
	})

	test("leaves gh commands unchanged outside a jj workspace", () => {
		expect(rewriteBashCommand("gh pr view", null)).toBe("gh pr view")
	})
})
