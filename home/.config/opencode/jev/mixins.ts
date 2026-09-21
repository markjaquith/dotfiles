import type { Context } from "@opencode-ai/plugin/tui/context"

export interface JevMixin {
	id: string
	label: string
	heuristic(question: string): boolean
	load(context: Context): Promise<unknown>
}

export interface ResolvedMixins {
	labels: string[]
	state: Record<string, unknown>
}

export const jevMixins: readonly JevMixin[] = [
	{
		id: "git",
		label: "Git",
		heuristic: (question) =>
			/\b(?:git|commit|status|committed)\b/i.test(question),
		load: async (context) => ({
			status: (await context.client.vcs.status({ location: context.location }))
				.data,
		}),
	},
]

export async function resolveMixins(
	context: Context,
	question: string,
): Promise<ResolvedMixins> {
	const matched = jevMixins.filter((mixin) => mixin.heuristic(question))
	const entries = await Promise.all(
		matched.map(
			async (mixin) => [mixin.id, await mixin.load(context)] as const,
		),
	)
	return {
		labels: matched.map((mixin) => mixin.label),
		state: Object.fromEntries(entries),
	}
}
