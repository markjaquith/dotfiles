import { describe, expect, test } from "bun:test"
import { rewriteGhCommands } from "../lib/jj-shell"

const prefix = "GIT_DIR=$(jj git root --ignore-working-copy) "

describe("rewriteGhCommands", () => {
	test.each([
		["gh pr view", `${prefix}gh pr view`],
		["echo ok && gh pr view", `echo ok && ${prefix}gh pr view`],
		["false || gh pr view", `false || ${prefix}gh pr view`],
		["echo ok; gh pr view", `echo ok; ${prefix}gh pr view`],
		["echo ok ;; gh pr view", `echo ok ;; ${prefix}gh pr view`],
		["echo ok | gh pr view", `echo ok | ${prefix}gh pr view`],
		["echo ok |& gh pr view", `echo ok |& ${prefix}gh pr view`],
		["sleep 1 & gh pr view", `sleep 1 & ${prefix}gh pr view`],
		["echo ok\ngh pr view", `echo ok\n${prefix}gh pr view`],
		["echo ok && \\\ngh pr view", `echo ok && \\\n${prefix}gh pr view`],
	])("rewrites gh at a command boundary: %s", (command, expected) => {
		expect(rewriteGhCommands(command)).toBe(expected)
	})

	test("rewrites commands in shell control structures and groups", () => {
		const command =
			"if gh auth status; then (gh pr view); else { gh repo view; }; fi"
		expect(rewriteGhCommands(command)).toBe(
			`if ${prefix}gh auth status; then (${prefix}gh pr view); else { ${prefix}gh repo view; }; fi`,
		)
	})

	test("rewrites every gh command in a compound command", () => {
		expect(
			rewriteGhCommands("gh pr view && gh pr checks || gh pr status"),
		).toBe(
			`${prefix}gh pr view && ${prefix}gh pr checks || ${prefix}gh pr status`,
		)
	})

	test("preserves leading environment assignments", () => {
		expect(rewriteGhCommands("GH_REPO=owner/repo gh pr view")).toBe(
			`GH_REPO=owner/repo ${prefix}gh pr view`,
		)
	})

	test("only skips a command that already has GIT_DIR", () => {
		expect(
			rewriteGhCommands("GIT_DIR=/tmp/repo gh pr view && gh pr status"),
		).toBe(`GIT_DIR=/tmp/repo gh pr view && ${prefix}gh pr status`)
	})

	test.each([
		"echo gh pr view",
		"echo '&& gh pr view'",
		'echo "|| gh pr view"',
		"printf '%s' gh",
		"echo > gh",
		"# gh pr view",
		"echo ok # gh pr view",
		"GIT_DIR=/tmp/repo gh pr view",
		`GIT_DIR=$(jj git root --ignore-working-copy) gh pr view`,
	])("does not rewrite a non-command or configured gh token: %s", (command) => {
		expect(rewriteGhCommands(command)).toBe(command)
	})

	test("does not rewrite heredoc contents", () => {
		const command = "cat <<'EOF'\ngh pr view\nEOF\ngh pr status"
		expect(rewriteGhCommands(command)).toBe(
			`cat <<'EOF'\ngh pr view\nEOF\n${prefix}gh pr status`,
		)
	})
})
