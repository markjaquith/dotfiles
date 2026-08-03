import { describe, expect, test } from "bun:test"
import { mkdirSync, mkdtempSync, realpathSync, rmSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"
import { getJjRoot, getJjSystemInstruction } from "../jj"

describe("jj", () => {
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
		expect(instruction).toContain("Prefer `jj` over `git`")
		expect(instruction).toContain("/workspace/example")
	})
})
