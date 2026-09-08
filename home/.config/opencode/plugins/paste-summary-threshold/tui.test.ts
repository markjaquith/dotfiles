import { describe, expect, test } from "bun:test"
import {
	MAX_INLINE_CHARACTERS,
	normalizePaste,
	shouldKeepPasteInline,
	SUMMARY_LINE_THRESHOLD,
} from "./policy.js"

describe("shouldKeepPasteInline", () => {
	test("leaves small pastes to native handling", () => {
		expect(shouldKeepPasteInline("short paste")).toBe(false)
	})

	test("keeps text inline between the native and custom character limits", () => {
		expect(shouldKeepPasteInline("x".repeat(151))).toBe(true)
		expect(shouldKeepPasteInline("x".repeat(MAX_INLINE_CHARACTERS))).toBe(true)
	})

	test("summarizes text beyond the custom character limit", () => {
		expect(shouldKeepPasteInline("x".repeat(MAX_INLINE_CHARACTERS + 1))).toBe(
			false,
		)
	})

	test("keeps nine lines inline and summarizes ten", () => {
		expect(shouldKeepPasteInline(Array(9).fill("line").join("\n"))).toBe(true)
		expect(
			shouldKeepPasteInline(
				Array(SUMMARY_LINE_THRESHOLD).fill("line").join("\n"),
			),
		).toBe(false)
	})
})

test("normalizePaste converts terminal newlines without trimming content", () => {
	const bytes = new TextEncoder().encode(" first\r\nsecond\r ")
	expect(normalizePaste(bytes)).toBe(" first\nsecond\n ")
})
