import { existsSync } from "node:fs"
import { spawn } from "node:child_process"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const COMPLETION_SOUND = "/System/Library/Sounds/Glass.aiff"
const ATTENTION_SOUND = "/System/Library/Sounds/Ping.aiff"
const PI_DING = "PI_DING"

function shouldPlayDings() {
	if (process.env[PI_DING] === "1") return true
	if (process.env[PI_DING] === "0") return false
	return process.platform === "darwin"
}

function playSound(sound: string) {
	if (!shouldPlayDings() || !existsSync(sound)) return

	const child = spawn("afplay", [sound], {
		stdio: "ignore",
		detached: true,
	})
	child.unref()
}

export default function (pi: ExtensionAPI) {
	let activeRootRun = false
	let hasInteractiveSession = false

	pi.on("session_start", (_event, ctx) => {
		hasInteractiveSession = ctx.mode === "tui"
		activeRootRun = ctx.isIdle() === false
	})

	pi.on("agent_start", () => {
		if (hasInteractiveSession) activeRootRun = true
	})

	pi.on("agent_settled", (_event, ctx) => {
		if (!hasInteractiveSession || !activeRootRun || !ctx.isIdle()) return
		activeRootRun = false
		playSound(COMPLETION_SOUND)
	})

	pi.events.on("herdr:blocked", (data) => {
		const blocked = data as { active?: boolean }
		if (hasInteractiveSession && blocked.active) {
			playSound(ATTENTION_SOUND)
		}
	})

	pi.events.on("pi:attention", () => {
		if (hasInteractiveSession) playSound(ATTENTION_SOUND)
	})
}
