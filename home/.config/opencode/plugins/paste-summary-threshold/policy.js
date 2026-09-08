export const MAX_INLINE_CHARACTERS = 2_048
export const SUMMARY_LINE_THRESHOLD = 10

const NATIVE_MAX_INLINE_CHARACTERS = 150
const NATIVE_SUMMARY_LINE_THRESHOLD = 3

/** @param {Uint8Array} bytes */
export function normalizePaste(bytes) {
	return new TextDecoder()
		.decode(bytes)
		.replace(/\r\n/g, "\n")
		.replace(/\r/g, "\n")
}

function exceedsThreshold(
	/** @type {string} */ text,
	/** @type {number} */ lineThreshold,
	/** @type {number} */ characterThreshold,
) {
	const content = text.trim()
	const lineCount = (content.match(/\n/g)?.length ?? 0) + 1
	return lineCount >= lineThreshold || content.length > characterThreshold
}

/** @param {string} text */
export function shouldKeepPasteInline(text) {
	return (
		exceedsThreshold(
			text,
			NATIVE_SUMMARY_LINE_THRESHOLD,
			NATIVE_MAX_INLINE_CHARACTERS,
		) && !exceedsThreshold(text, SUMMARY_LINE_THRESHOLD, MAX_INLINE_CHARACTERS)
	)
}
