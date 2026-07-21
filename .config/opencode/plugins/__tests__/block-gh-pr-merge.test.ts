import { describe, expect, test } from "bun:test"
import { mkdtempSync, rmSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"
import {
	evaluateToolCall,
	getCurrentRepository,
	normalizeGitHubRepository,
	type ToolCall,
} from "../block-gh-pr-merge"

function bash(command: string): ToolCall {
	return { tool: "bash", command }
}

describe("block-gh-pr-merge", () => {
	test("allows merges in an allowlisted current repository", () => {
		expect(
			evaluateToolCall(bash("gh pr merge 123 --squash"), "markjaquith/agency"),
		).toEqual({ blocked: false })
	})

	test("blocks merges in other repositories", () => {
		expect(evaluateToolCall(bash("gh pr merge 123"), "example/other")).toEqual({
			blocked: true,
			reason: expect.stringContaining('repository "example/other"'),
		})
	})

	test("blocks merges when the repository cannot be determined", () => {
		expect(evaluateToolCall(bash("gh pr merge 123"), null).blocked).toBe(true)
	})

	test("explicit --repo overrides the current repository", () => {
		expect(
			evaluateToolCall(
				bash("gh pr merge 123 --repo example/other"),
				"markjaquith/agency",
			).blocked,
		).toBe(true)
	})

	test("an explicit allowlisted PR URL is allowed", () => {
		expect(
			evaluateToolCall(
				bash("gh pr merge https://github.com/markjaquith/agency/pull/123"),
				"example/other",
			),
		).toEqual({ blocked: false })
	})

	test("GH_REPO overrides the current repository", () => {
		expect(
			evaluateToolCall(
				bash("GH_REPO=example/other gh pr merge 123"),
				"markjaquith/agency",
			).blocked,
		).toBe(true)
	})

	test("allows unrelated commands", () => {
		expect(evaluateToolCall(bash("gh pr view 123"), "example/other")).toEqual({
			blocked: false,
		})
	})

	test("normalizes supported GitHub remote formats", () => {
		expect(
			normalizeGitHubRepository("git@github.com:MarkJaquith/agency.git"),
		).toBe("markjaquith/agency")
		expect(
			normalizeGitHubRepository("https://github.com/markjaquith/agency.git"),
		).toBe("markjaquith/agency")
	})

	test("determines the repository from the origin remote", () => {
		const directory = mkdtempSync(join(tmpdir(), "gh-pr-merge-guard-"))
		try {
			Bun.spawnSync(["git", "init"], { cwd: directory })
			Bun.spawnSync(
				[
					"git",
					"remote",
					"add",
					"origin",
					"git@github.com:markjaquith/agency.git",
				],
				{ cwd: directory },
			)
			expect(getCurrentRepository(directory)).toBe("markjaquith/agency")
		} finally {
			rmSync(directory, { recursive: true, force: true })
		}
	})
})
