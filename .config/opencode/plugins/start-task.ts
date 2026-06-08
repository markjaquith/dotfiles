import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

const TRIGGER = "Start the task"
const TASK_FILE = "TASK.md"

const taskBySession = new Map<string, string>()

type MessagePart = {
	type: string
	ignored?: boolean
	text?: string
}

function textFromParts(parts: MessagePart[]) {
	return parts
		.filter(
			(part): part is MessagePart & { type: "text"; text: string } =>
				part.type === "text" && !part.ignored && typeof part.text === "string",
		)
		.map((part) => part.text)
		.join("\n")
		.trim()
}

function isTrigger(parts: MessagePart[]) {
	return textFromParts(parts) === TRIGGER
}

function isTitleGenerator(system: string[]) {
	return system.some((entry) => {
		const lower = entry.toLowerCase()
		return (
			lower.includes("title generator") || lower.includes("generate a title")
		)
	})
}

async function fileExists(path: string) {
	return await Bun.file(path).exists()
}

async function readTaskFile(worktree: string, directory: string) {
	const candidates = [join(worktree, TASK_FILE), join(directory, TASK_FILE)]
	for (const candidate of candidates) {
		if (await fileExists(candidate)) {
			return await Bun.file(candidate).text()
		}
	}

	return null
}

async function isFirstUserMessage(
	client: Parameters<Plugin>[0]["client"],
	sessionID: string,
) {
	try {
		const { data: messages = [] } = await client.session.messages({
			path: { id: sessionID },
		})

		const userMessages = messages.filter(
			(message) => message.info.role === "user",
		)
		return userMessages.length <= 1
	} catch {
		return false
	}
}

function buildTaskPrompt(task: string) {
	return `${TRIGGER}

Use ${TASK_FILE} as the context initiation bundle for this session.

<TASK.md>
${task.trim()}
</TASK.md>`
}

function buildTitleContext(task: string) {
	return `The user's exact first message was "${TRIGGER}", which means ${TASK_FILE} is the actual task context. Use the task below when generating the session title. Prefer a short, specific title that describes this task, not the trigger phrase.

<TASK.md>
${task.trim()}
</TASK.md>`
}

function replaceTextParts(parts: MessagePart[], text: string) {
	let replaced = false
	for (const part of parts) {
		if (part.type !== "text" || part.ignored || typeof part.text !== "string") {
			continue
		}

		part.text = replaced ? "" : text
		replaced = true
	}
}

function taskForTitleGenerator(sessionID: string | undefined) {
	if (sessionID) {
		return taskBySession.get(sessionID)
	}

	if (taskBySession.size !== 1) {
		return undefined
	}

	return taskBySession.values().next().value
}

export const StartTaskPlugin: Plugin = async ({
	client,
	directory,
	worktree,
}) => {
	return {
		async "chat.message"(input, output) {
			if (!isTrigger(output.parts)) {
				return
			}

			if (!(await isFirstUserMessage(client, input.sessionID))) {
				return
			}

			const task = await readTaskFile(worktree, directory)
			if (!task) {
				return
			}

			taskBySession.set(input.sessionID, task)
			replaceTextParts(output.parts, buildTaskPrompt(task))
		},

		async "experimental.chat.system.transform"(input, output) {
			if (!isTitleGenerator(output.system)) {
				return
			}

			const task = taskForTitleGenerator(input.sessionID)
			if (!task) {
				return
			}

			output.system.push(buildTitleContext(task))
		},
	}
}
