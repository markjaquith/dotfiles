import type { Context } from "@opencode-ai/plugin/tui/context"
import { percentageBar } from "./bar"
import { evaluateNoul } from "./client"
import { lastConversationMessages } from "./messages"
import { resolveMixins } from "./mixins"

interface JevEvaluation {
	inboxID: string
	question: string
	noul: number
}

export default {
	id: "jev",
	setup(context: Context) {
		const history = new Map<string, JevEvaluation[]>()
		const queues = new Map<string, Promise<void>>()
		const generations = new Map<string, number>()
		const clear = async (sessionID: string) => {
			generations.set(sessionID, (generations.get(sessionID) ?? 0) + 1)
			const evaluations = history.get(sessionID)
			if (!evaluations) return

			history.delete(sessionID)
			await Promise.all(
				evaluations.map((evaluation) =>
					context.client.session.inbox.cancel({
						sessionID,
						inboxID: evaluation.inboxID,
					}),
				),
			)
		}
		const stop = context.data.on("session.inbox.enqueued", (event) => {
			if (event.data.item.type !== "user") return
			void clear(event.data.sessionID)
		})
		const removeSlot = context.ui.slot({
			append: "app",
			render: () => {
				context.keymap.layer(() => ({
					mode: "global",
					commands: [
						{
							id: "jev.evaluate",
							title: "Evaluate with Jev",
							description: "Evaluate a question about the last four messages",
							slash: { name: "jev", arguments: true },
							run: async (input) => {
								const question = input?.trim()
								const route = context.ui.router.current()
								if (route.type !== "session") {
									context.ui.toast.show({
										message: "/jev can only be used inside a session.",
										variant: "error",
									})
									return
								}
								if (!question) {
									context.ui.toast.show({
										message: "Usage: /jev <question>",
										variant: "error",
									})
									return
								}

								const generation = generations.get(route.sessionID) ?? 0
								const previous =
									queues.get(route.sessionID) ?? Promise.resolve()
								const evaluation = previous
									.catch(() => {})
									.then(async () => {
										if ((generations.get(route.sessionID) ?? 0) !== generation)
											return

										const messages = await context.client.session.context({
											sessionID: route.sessionID,
										})
										const previousEvaluations =
											history.get(route.sessionID) ?? []
										const mixins = await resolveMixins(context, question)
										const noul = await evaluateNoul({
											state: {
												messages: lastConversationMessages(messages),
												jev: previousEvaluations.map(({ question, noul }) => ({
													question,
													answer: noul,
												})),
												...(mixins.labels.length === 0
													? {}
													: { mixins: mixins.state }),
											},
											question,
										})
										if ((generations.get(route.sessionID) ?? 0) !== generation)
											return

										const mixinDescription =
											mixins.labels.length === 0
												? ""
												: ` · ${mixins.labels.join(", ")}`
										const result = await context.client.session.synthetic({
											sessionID: route.sessionID,
											text: percentageBar(noul),
											description: `Jev · ${percentageBar(noul)}${mixinDescription} · ${question}`,
											metadata: { source: "jev", noul },
											delivery: "queue",
											resume: false,
										})
										if (
											(generations.get(route.sessionID) ?? 0) !== generation
										) {
											await context.client.session.inbox.cancel({
												sessionID: route.sessionID,
												inboxID: result.id,
											})
											return
										}

										previousEvaluations.push({
											inboxID: result.id,
											question,
											noul,
										})
										history.set(route.sessionID, previousEvaluations)
									})
								queues.set(route.sessionID, evaluation)

								try {
									await evaluation
								} catch (error) {
									context.ui.toast.show({
										title: "Jev evaluation failed",
										message:
											error instanceof Error ? error.message : String(error),
										variant: "error",
										duration: 8_000,
									})
								} finally {
									if (queues.get(route.sessionID) === evaluation) {
										queues.delete(route.sessionID)
									}
								}
							},
						},
					],
				}))
				return null
			},
		})
		return () => {
			stop()
			removeSlot()
		}
	},
}
