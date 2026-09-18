const WIDTH = 10
const FRACTIONS = ["", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]

export function percentageBar(value: number) {
	const scaled = value * WIDTH
	let full = Math.floor(scaled)
	let fraction = Math.round((scaled - full) * 8)
	if (fraction === 8) {
		full++
		fraction = 0
	}
	const partial = FRACTIONS[fraction] ?? ""
	const empty = " ".repeat(WIDTH - full - (partial ? 1 : 0))
	const percentage = Math.round(value * 100)
	const paddedPercentage = percentage < 10 ? ` ${percentage}` : percentage
	return `│${"█".repeat(full)}${partial}${empty}│ ${paddedPercentage}%`
}
