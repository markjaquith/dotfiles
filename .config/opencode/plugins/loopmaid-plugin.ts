// Loopmaid OpenCode plugin
import { tool, type Plugin } from "@opencode-ai/plugin"

const defaultLoopmaidUrl = "http://localhost:9393"

function loopmaidUrl() {
	return (process.env.LOOPMAID_URL || defaultLoopmaidUrl).replace(/\/$/, "")
}

async function postLoopmaid(path: string, body: unknown) {
	let response: Response
	try {
		response = await fetch(`${loopmaidUrl()}${path}`, {
			method: "POST",
			headers: {
				"content-type": "application/json",
				accept: "application/json",
			},
			body: JSON.stringify(body),
		})
	} catch {
		throw new Error(
			"Loopmaid server is not responding. Run `loopmaid server start`, then retry this tool call.",
		)
	}

	const text = await response.text()
	const payload = text ? JSON.parse(text) : null

	if (!response.ok) {
		const message =
			payload && typeof payload.message === "string"
				? payload.message
				: `Loopmaid returned HTTP ${response.status}.`
		throw new Error(message)
	}

	return payload
}

export const LoopmaidPlugin: Plugin = async () => {
	return {
		tool: {
			loopmaid_create_loop: tool({
				description:
					"Create a Loopmaid loop from a Mermaid flowchart and initial loop variables. Before the first Loopmaid call in a session, run `loopmaid server start`; if a call reports that the server stopped responding, run it again and retry. Returns the loop id and viewer URL.",
				args: {
					title: tool.schema
						.string()
						.optional()
						.describe("Optional loop title."),
					mermaid: tool.schema.string().describe("Mermaid flowchart source."),
					variables: tool.schema
						.any()
						.optional()
						.describe("Initial JSON variables to display next to the diagram."),
					activeNodeId: tool.schema
						.string()
						.optional()
						.describe("Optional initial Mermaid node id for the current step."),
					message: tool.schema
						.string()
						.optional()
						.describe("Optional message for the initial timeline event."),
				},
				async execute(args, context) {
					const payload = await postLoopmaid("/api/loops", args)
					context.metadata({
						title: `Loopmaid ${payload.id}`,
						metadata: { id: payload.id, url: payload.url },
					})

					return {
						title: `Created Loopmaid loop ${payload.id}`,
						output: JSON.stringify(payload, null, 2),
						metadata: { id: payload.id, url: payload.url },
					}
				},
			}),

			loopmaid_update_loop: tool({
				description:
					"Append a Loopmaid timeline event for one visited Mermaid node. Before the first Loopmaid call in a session, run `loopmaid server start`; if a call reports that the server stopped responding, run it again and retry. Call this once for every node visited, including decision nodes, before continuing to the selected branch. For a decision node, include the selected outcome in decision.",
				args: {
					loopId: tool.schema
						.string()
						.describe("Loopmaid loop id returned by loopmaid_create_loop."),
					activeNodeId: tool.schema
						.string()
						.optional()
						.describe("Mermaid node id for the current loop step."),
					variables: tool.schema
						.any()
						.optional()
						.describe("Current JSON variables to display next to the diagram."),
					decision: tool.schema
						.string()
						.optional()
						.describe(
							'For a decision node, the condition result and selected branch, such as "Tests pass: no; selected fix failures".',
						),
					message: tool.schema
						.string()
						.optional()
						.describe("Optional short timeline note."),
				},
				async execute(args, context) {
					const { loopId, decision, message, ...event } = args
					const timelineMessage =
						[decision ? `Decision: ${decision}` : null, message]
							.filter(Boolean)
							.join(". ") || undefined
					const payload = await postLoopmaid(
						`/api/loops/${encodeURIComponent(loopId)}/events`,
						{
							...event,
							message: timelineMessage,
						},
					)
					context.metadata({
						title: `Loopmaid ${loopId}`,
						metadata: { loopId, eventId: payload.event?.id },
					})

					return {
						title: `Updated Loopmaid loop ${loopId}`,
						output: JSON.stringify(payload, null, 2),
						metadata: { loopId, eventId: payload.event?.id },
					}
				},
			}),
		},
	}
}

export default LoopmaidPlugin
