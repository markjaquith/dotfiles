import { describe, expect, mock, test } from "bun:test"

mock.module("@earendil-works/pi-coding-agent", () => ({
	isToolCallEventType: () => false,
}))

const { evaluateBashCommand, getJjSystemInstruction, rewriteBashCommand } =
	await import("./jj")

describe("Pi jj extension", () => {
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
	])("allows non-git commands in a jj workspace: %s", (command) => {
		expect(evaluateBashCommand(command, "/workspace/example")).toEqual({
			blocked: false,
		})
	})

	test("allows raw git outside a jj workspace", () => {
		expect(evaluateBashCommand("git status", null)).toEqual({ blocked: false })
	})

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
