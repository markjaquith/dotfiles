import * as Plugin from "@opencode-ai/plugin/tui/plugin"
import type { OpenCodeEvent } from "@opencode-ai/client"
import selection from "../../herdr-tui-session.js"
import { HerdrAgentStatePlugin } from "../../legacy-integrations/herdr-agent-state.js"

// Register this DIRECTORY in cli.json: beta resolves its tui.ts entry point.
// Mini does not run TUI plugins: pane attribution there remains unresolved.
// Caller/install guard required: a Herdr reinstall can restore the managed
// plugins/herdr-agent-state.js, re-enabling unsafe shared-server reporting.
type Context = Pick<Plugin.Context, "data" | "ui">

export async function setup(context: Context) {
	if (
		process.env.HERDR_ENV !== "1" ||
		!process.env.HERDR_PANE_ID ||
		!process.env.HERDR_SOCKET_PATH
	)
		return

	const state = await HerdrAgentStatePlugin()
	const sessions = new Map<string, { id: string; parentID?: string }>()
	let disposed = false
	let chain = Promise.resolve()
	const disposers: (() => void)[] = []
	let selected: string | undefined

	function root(id: string): string | undefined {
		const seen = new Set<string>()
		while (!seen.has(id)) {
			seen.add(id)
			const session = context.data.session.get(id) ?? sessions.get(id)
			if (!session) return
			if (!session.parentID) return id
			id = session.parentID
		}
	}

	function current() {
		if (disposed) return
		for (const session of context.data.session.list()) {
			sessions.set(session.id, session)
		}
		const route = context.ui.router.current()
		return route.type === "session" ? root(route.sessionID) : undefined
	}

	function report(type: string, sessionID: string, status?: unknown) {
		chain = chain
			.then(async () => {
				if (disposed || current() !== sessionID) return
				await state.event?.({
					event: { type, properties: { sessionID, status } },
				})
			})
			.catch(() => {})
	}

	function receive(event: OpenCodeEvent) {
		const data = event.data
		const id =
			event.type === "form.created"
				? event.data.form.sessionID
				: "sessionID" in data
					? data.sessionID
					: undefined
		const selectedRoot = current()
		if (typeof id !== "string" || !selectedRoot || root(id) !== selectedRoot)
			return
		let type: string = event.type
		if (type === "form.created") type = "question.asked"
		if (type === "form.replied") type = "question.replied"
		if (type === "form.cancelled") type = "question.rejected"
		if (type === "session.execution.started") type = "tool.execute.before"
		if (type === "session.execution.failed") type = "session.error"
		// Child activity must not turn an idle/blocked root into working or idle.
		if (
			id !== selectedRoot &&
			![
				"permission.asked",
				"permission.replied",
				"question.asked",
				"question.replied",
				"question.rejected",
			].includes(type)
		)
			return
		report(
			type,
			selectedRoot,
			event.type === "session.status" ? event.data.status : undefined,
		)
	}

	disposers.push(
		context.data.on("session.created", (event) => {
			sessions.set(event.data.sessionID, {
				id: event.data.sessionID,
				parentID: event.data.parentID,
			})
		}),
	)
	disposers.push(context.data.listen(({ details }) => receive(details)))
	try {
		await selection.tui({
			route: {
				get current() {
					const sessionID = current()
					if (sessionID !== selected) {
						selected = sessionID
						if (sessionID) {
							const family = context.data.session.family(sessionID)
							const blocked = [sessionID, ...family].some(
								(id) =>
									root(id) === sessionID &&
									((context.data.session.permission.list(id)?.length ?? 0) >
										0 ||
										(context.data.session.form.list(id)?.length ?? 0) > 0),
							)
							report(
								blocked ? "permission.asked" : "session.status",
								sessionID,
								context.data.session.status(sessionID),
							)
						}
					}
					return { name: "session", params: { sessionID } }
				},
			},
			state: {
				session: {
					get: (id: string) => context.data.session.get(id) ?? sessions.get(id),
				},
			},
			lifecycle: {
				onDispose: (dispose: () => void) => disposers.push(dispose),
			},
		})
	} catch (error) {
		disposed = true
		for (const dispose of disposers) dispose()
		throw error
	}
	return async () => {
		disposed = true
		for (const dispose of disposers) dispose()
		await chain
	}
}

export default Plugin.define({ id: "dotfiles.herdr", setup })
