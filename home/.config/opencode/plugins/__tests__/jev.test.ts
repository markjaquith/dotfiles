import { afterEach, describe, expect, mock, test } from "bun:test"
import { percentageBar } from "../../jev/bar"
import { evaluateNoul } from "../../jev/client"
import { lastConversationMessages } from "../../jev/messages"
import jevPlugin from "../../jev/tui"

const originalFetch = globalThis.fetch
const originalOpenRouterKey = process.env.OPENROUTER_API_KEY
const originalTypesafeKey = process.env.TYPESAFE_API_KEY

afterEach(() => {
	globalThis.fetch = originalFetch
	if (originalOpenRouterKey === undefined) delete process.env.OPENROUTER_API_KEY
	else process.env.OPENROUTER_API_KEY = originalOpenRouterKey
	if (originalTypesafeKey === undefined) delete process.env.TYPESAFE_API_KEY
	else process.env.TYPESAFE_API_KEY = originalTypesafeKey
})

describe("Jev client", () => {
	test("prefers OpenRouter and requests a Noul", async () => {
		process.env.OPENROUTER_API_KEY = "openrouter-test-key"
		process.env.TYPESAFE_API_KEY = "typesafe-test-key"
		globalThis.fetch = mock(async (_url, init) => {
			const body = JSON.parse(String(init?.body))
			expect(body.model).toBe("typesafe/jev-1.13")
			expect(body.questions.evaluation).toEqual({
				type: "noul",
				instructions: "Was it fixed?",
			})
			return Response.json({
				answers: { evaluation: { type: "noul", noul: 0.82 } },
			})
		}) as unknown as typeof fetch

		await expect(
			evaluateNoul({ state: { messages: [] }, question: "Was it fixed?" }),
		).resolves.toBe(0.82)
	})

	test("uses TypeSafe when OpenRouter is absent", async () => {
		delete process.env.OPENROUTER_API_KEY
		process.env.TYPESAFE_API_KEY = "typesafe-test-key"
		globalThis.fetch = mock(async (_url, init) => {
			const body = JSON.parse(String(init?.body))
			expect(body.model).toBe("jev-latest")
			return Response.json({
				answers: { evaluation: { type: "noul", noul: 0.2 } },
			})
		}) as unknown as typeof fetch

		await expect(
			evaluateNoul({ state: "context", question: "True?" }),
		).resolves.toBe(0.2)
	})
})

test("keeps only the last four conversation messages", () => {
	const messages = [
		{ type: "system", text: "ignore" },
		{ type: "user", text: "one" },
		{ type: "assistant", content: [{ type: "text", text: "two" }] },
		{ type: "user", text: "three" },
		{ type: "assistant", content: [{ type: "reasoning", text: "hidden" }] },
		{ type: "user", text: "five" },
	] as unknown as Parameters<typeof lastConversationMessages>[0]

	expect(lastConversationMessages(messages)).toEqual([
		{ role: "assistant", content: [{ type: "text", text: "two" }] },
		{ role: "user", content: "three" },
		{ role: "assistant", content: [] },
		{ role: "user", content: "five" },
	])
})

test("formats fractional percentage bars without control characters", () => {
	expect(percentageBar(0.01)).toBe(" │▏         │  1%")
	expect(percentageBar(0.149)).toStartWith(" ")
	expect(percentageBar(0.15)).toStartWith(" ")
	expect(percentageBar(0.7)).toContain("│███████   │ 70%")
	expect(percentageBar(0.725)).toContain("│███████▎  │ 73%")
	expect(percentageBar(0.75)).toContain("│███████▌  │ 75%")
	expect(percentageBar(0.775)).toContain("│███████▊  │ 78%")
	expect(percentageBar(0.849)).toStartWith(" ")
	expect(percentageBar(0.85)).toStartWith(" ")
	expect(percentageBar(0.7)).toEndWith("70%")
	expect(percentageBar(0.7)).not.toContain("\u001b")
})

test("registers its keymap inside the TUI app provider", () => {
	let render: (() => unknown) | undefined
	let keymapRegistrations = 0
	const context = {
		data: {
			on: () => () => {},
		},
		ui: {
			slot: (claim: { render: () => unknown }) => {
				render = claim.render
				return () => {}
			},
		},
		keymap: {
			layer: () => {
				keymapRegistrations++
			},
		},
	} as unknown as Parameters<typeof jevPlugin.setup>[0]

	jevPlugin.setup(context)
	expect(keymapRegistrations).toBe(0)
	expect(render).toBeFunction()
	render?.()
	expect(keymapRegistrations).toBe(1)
})

test("retains consecutive Jev results as context until the user sends a message", async () => {
	process.env.OPENROUTER_API_KEY = "openrouter-test-key"
	const states: unknown[] = []
	const answers = [0.73, 0.81, 0.44]
	globalThis.fetch = mock(async (_url, init) => {
		states.push(JSON.parse(String(init?.body)).state)
		return Response.json({
			answers: {
				evaluation: { type: "noul", noul: answers[states.length - 1] },
			},
		})
	}) as unknown as typeof fetch

	let render: (() => unknown) | undefined
	let run: ((input?: string) => Promise<void>) | undefined
	let onEnqueued:
		| ((event: { data: { sessionID: string; item: { type: "user" } } }) => void)
		| undefined
	const cancelled: Array<{ sessionID: string; inboxID: string }> = []
	let syntheticCount = 0
	const context = {
		client: {
			session: {
				context: async () => [],
				synthetic: async () => ({ id: `msg_jev_${++syntheticCount}` }),
				inbox: {
					cancel: async (input: { sessionID: string; inboxID: string }) => {
						cancelled.push(input)
					},
				},
			},
		},
		data: {
			on: (_event: string, handler: typeof onEnqueued) => {
				onEnqueued = handler
				return () => {}
			},
		},
		ui: {
			router: { current: () => ({ type: "session", sessionID: "ses_test" }) },
			slot: (claim: { render: () => unknown }) => {
				render = claim.render
				return () => {}
			},
			toast: { show: () => {} },
		},
		keymap: {
			layer: (
				factory: () => {
					commands: Array<{ run: (input?: string) => Promise<void> }>
				},
			) => {
				run = factory().commands[0]?.run
			},
		},
	} as unknown as Parameters<typeof jevPlugin.setup>[0]

	jevPlugin.setup(context)
	render?.()
	await run?.("Is it fixed?")
	await run?.("Is it definitely fixed?")

	expect(cancelled).toEqual([])
	expect(states).toEqual([
		{ messages: [], jev: [] },
		{
			messages: [],
			jev: [{ question: "Is it fixed?", answer: 0.73 }],
		},
	])

	onEnqueued?.({
		data: { sessionID: "ses_test", item: { type: "user" } },
	})
	await Promise.resolve()

	expect(cancelled).toEqual([
		{ sessionID: "ses_test", inboxID: "msg_jev_1" },
		{ sessionID: "ses_test", inboxID: "msg_jev_2" },
	])

	await run?.("Did the new message change things?")
	expect(states[2]).toEqual({ messages: [], jev: [] })
})
