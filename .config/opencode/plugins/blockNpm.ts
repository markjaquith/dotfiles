import type { Plugin, PluginModule } from "@opencode-ai/plugin/v1"

export const BlockNpm: Plugin = async () => ({})

// export const BlockNpm: Plugin = async ({ client }) => {
// 	return {
// 		async ["tool.execute.before"](input) {
// 			if (input.tool === 'bash') {
//
// 				input.callID
// 			}
// 			client.app.log({
// 				body: {
// 					service: "BlockNpm",
// 					level: "info",
// 					message: "Tool execution requested: " + JSON.stringify(input),
// 				},
// 			})
// 			throw new Error("NO EXECUTION ALLOWED")
// 		},
// 	}
// }

export default {
	id: "block-npm",
	server: BlockNpm,
} satisfies PluginModule
