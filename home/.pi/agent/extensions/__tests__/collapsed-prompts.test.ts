import { describe, expect, mock, test } from "bun:test"

const promptFile = [
	"---",
	"description: Test prompt",
	"---",
	"Review $1 with $@ and ${2:-fallback}",
].join("\n")

mock.module("node:fs/promises", () => ({
	readFile: async () => promptFile,
}))

mock.module("@earendil-works/pi-coding-agent", () => ({
	isToolCallEventType: () => false,
	parseFrontmatter: (content: string) => {
		const match = content.match(/^---\n[\s\S]*?\n---\n?([\s\S]*)$/)
		return { frontmatter: {}, body: (match?.[1] ?? content).trim() }
	},
}))

class MockText {
	constructor(
		readonly text: string,
		readonly paddingX: number,
		readonly paddingY: number,
	) {}
}

mock.module("@earendil-works/pi-tui", () => ({ Text: MockText }))

const {
	default: collapsedPrompts,
	expandPrompt,
	parsePromptArgs,
	parsePromptInvocation,
	substitutePromptArgs,
} = await import("../collapsed-prompts")

describe("collapsed Pi prompts", () => {
	test("parses prompt invocations", () => {
		expect(parsePromptInvocation("/jj-desc")).toEqual({
			name: "jj-desc",
			argsString: "",
		})
		expect(parsePromptInvocation('/review "one two" three')).toEqual({
			name: "review",
			argsString: '"one two" three',
		})
		expect(parsePromptInvocation("regular message")).toBeUndefined()
	})

	test("parses quoted prompt arguments", () => {
		expect(parsePromptArgs(`one "two three" 'four five'`)).toEqual([
			"one",
			"two three",
			"four five",
		])
	})

	test("matches Pi prompt argument substitution", () => {
		const template = [
			"first=$1",
			"all=$@",
			"named=$ARGUMENTS",
			"default=${3:-fallback}",
			"allDefault=${@:-fallback}",
			"slice=${@:2}",
			"limited=${@:2:1}",
		].join("\n")

		expect(substitutePromptArgs(template, ["one", "two"])).toBe(
			[
				"first=one",
				"all=one two",
				"named=one two",
				"default=fallback",
				"allDefault=one two",
				"slice=two",
				"limited=two",
			].join("\n"),
		)
	})

	test("strips frontmatter before expanding", () => {
		expect(expandPrompt(promptFile, '"one two" three')).toBe(
			"Review one two with one two three and three",
		)
	})

	test("replaces a TUI prompt with an always-collapsed custom message", async () => {
		let inputHandler: ((event: any, ctx: any) => Promise<unknown>) | undefined
		let renderer:
			| ((message: any, options: any, theme: any) => unknown)
			| undefined
		const sent: Array<{ message: any; options: any }> = []
		const pi = {
			registerMessageRenderer: (_type: string, value: typeof renderer) => {
				renderer = value
			},
			on: (event: string, handler: typeof inputHandler) => {
				if (event === "input") inputHandler = handler
			},
			getCommands: () => [
				{
					name: "review",
					source: "prompt",
					sourceInfo: { path: "/prompt.md" },
				},
			],
			sendMessage: (message: any, options: any) => {
				sent.push({ message, options })
			},
		}

		collapsedPrompts(pi as any)
		const result = await inputHandler?.(
			{ text: '/review "one two" three' },
			{ mode: "tui" },
		)

		expect(result).toEqual({ action: "handled" })
		expect(sent).toEqual([
			{
				message: {
					customType: "collapsed-prompt",
					content: "Review one two with one two three and three",
					display: true,
					details: { command: "/review" },
				},
				options: { triggerTurn: true },
			},
		])

		const collapsed = renderer?.(
			{ details: { command: "/review" } },
			{ expanded: false, outputPad: 1 },
			{ fg: (_color: string, value: string) => value },
		)
		const expanded = renderer?.(
			{ details: { command: "/review" } },
			{ expanded: true, outputPad: 1 },
			{ fg: (_color: string, value: string) => value },
		)

		expect(collapsed).toEqual(new MockText("/review", 1, 0))
		expect(expanded).toEqual(new MockText("/review", 1, 0))
	})

	test("leaves prompts unchanged outside the TUI", async () => {
		let inputHandler: ((event: any, ctx: any) => Promise<unknown>) | undefined
		const pi = {
			registerMessageRenderer: () => {},
			on: (_event: string, handler: typeof inputHandler) => {
				inputHandler = handler
			},
		}

		collapsedPrompts(pi as any)
		expect(await inputHandler?.({ text: "/review" }, { mode: "rpc" })).toEqual({
			action: "continue",
		})
	})
})
