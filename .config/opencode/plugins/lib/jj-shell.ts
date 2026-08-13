const GH_GIT_DIR_PREFIX = "GIT_DIR=$(jj git root --ignore-working-copy) "

const commandStarters = new Set([
	"do",
	"elif",
	"else",
	"if",
	"then",
	"time",
	"until",
	"while",
])

const assignmentPattern = /^([A-Za-z_][A-Za-z0-9_]*)=/

interface CommandState {
	expectsCommand: boolean
	hasGitDir: boolean
}

interface Heredoc {
	delimiter: string
	stripTabs: boolean
}

function readQuoted(command: string, start: number, quote: string): number {
	let index = start + 1
	while (index < command.length) {
		if (quote !== "'" && command[index] === "\\") {
			index += 2
			continue
		}
		if (command[index] === quote) return index + 1
		index++
	}
	return index
}

function readWord(command: string, start: number): number {
	let index = start
	while (index < command.length) {
		const char = command[index]
		if (!char || /[\s;&|<>(){}]/.test(char)) break
		if (char === "\\") {
			index += 2
			continue
		}
		if (char === "'" || char === '"' || char === "`") {
			index = readQuoted(command, index, char)
			continue
		}
		index++
	}
	return index
}

function heredocDelimiter(word: string): string {
	return word.replace(/["'\\]/g, "")
}

function skipHeredocs(
	command: string,
	start: number,
	heredocs: Heredoc[],
): number {
	let index = start
	for (const heredoc of heredocs) {
		while (index < command.length) {
			const newline = command.indexOf("\n", index)
			const end = newline === -1 ? command.length : newline
			const line = command.slice(index, end)
			const candidate = heredoc.stripTabs ? line.replace(/^\t+/, "") : line
			index = newline === -1 ? end : newline + 1
			if (candidate === heredoc.delimiter) break
		}
	}
	return index
}

export function rewriteGhCommands(command: string): string {
	const insertions: number[] = []
	const groups: CommandState[] = []
	const heredocs: Heredoc[] = []
	let state: CommandState = { expectsCommand: true, hasGitDir: false }
	let redirectionTarget: { heredoc: boolean; stripTabs: boolean } | null = null
	let index = 0

	const startCommand = () => {
		state = { expectsCommand: true, hasGitDir: false }
	}

	while (index < command.length) {
		const char = command[index]

		if (char === "\\" && command[index + 1] === "\n") {
			index += 2
			continue
		}

		if (char === " " || char === "\t" || char === "\r") {
			index++
			continue
		}

		if (char === "\n") {
			index++
			startCommand()
			if (heredocs.length > 0) {
				index = skipHeredocs(command, index, heredocs.splice(0))
			}
			continue
		}

		if (char === "#") {
			const newline = command.indexOf("\n", index)
			index = newline === -1 ? command.length : newline
			continue
		}

		if (/\d/.test(char ?? "")) {
			const descriptor = command.slice(index).match(/^\d+(?=[<>])/)?.[0]
			if (descriptor) {
				index += descriptor.length
				continue
			}
		}

		const twoChars = command.slice(index, index + 2)
		const threeChars = command.slice(index, index + 3)
		if (char === "<" || char === ">") {
			const heredoc = twoChars === "<<"
			const stripTabs = threeChars === "<<-"
			if (stripTabs) index += 3
			else if (["<<", ">>", "<>", ">&", "<&", ">|"].includes(twoChars)) {
				index += 2
			} else index++
			redirectionTarget = { heredoc, stripTabs }
			continue
		}

		if (char === "(" || char === "{") {
			groups.push(state)
			startCommand()
			index++
			continue
		}

		if (char === ")" || char === "}") {
			state = groups.pop() ?? { expectsCommand: false, hasGitDir: false }
			index++
			continue
		}

		if (threeChars === ";;&") {
			startCommand()
			index += 3
			continue
		}

		if (["&&", "||", ";;", ";&", "|&"].includes(twoChars)) {
			startCommand()
			index += 2
			continue
		}

		if (char === ";" || char === "|" || char === "&") {
			startCommand()
			index++
			continue
		}

		if (char === "!" && state.expectsCommand) {
			index++
			continue
		}

		const wordStart = index
		const wordEnd = readWord(command, wordStart)
		if (wordEnd === wordStart) {
			index++
			continue
		}

		const word = command.slice(wordStart, wordEnd)
		index = wordEnd

		if (redirectionTarget) {
			if (redirectionTarget.heredoc) {
				heredocs.push({
					delimiter: heredocDelimiter(word),
					stripTabs: redirectionTarget.stripTabs,
				})
			}
			redirectionTarget = null
			continue
		}

		if (!state.expectsCommand) continue

		const assignment = word.match(assignmentPattern)
		if (assignment) {
			if (assignment[1] === "GIT_DIR") state.hasGitDir = true
			continue
		}

		if (commandStarters.has(word)) continue

		if (word === "gh") {
			if (!state.hasGitDir) insertions.push(wordStart)
		}
		state.expectsCommand = false
	}

	let rewritten = command
	for (const insertion of insertions.reverse()) {
		rewritten =
			rewritten.slice(0, insertion) +
			GH_GIT_DIR_PREFIX +
			rewritten.slice(insertion)
	}
	return rewritten
}
