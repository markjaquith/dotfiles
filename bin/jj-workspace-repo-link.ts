#!/usr/bin/env bun

import {
	closeSync,
	fsyncSync,
	openSync,
	renameSync,
	unlinkSync,
	writeFileSync,
} from "node:fs"
import { dirname, relative, resolve } from "node:path"

function die(message: string): never {
	console.error(`jj-workspace-repo-link: ${message}`)
	process.exit(1)
}

const [workspaceRoot, repoPath] = process.argv.slice(2)
if (!workspaceRoot || !repoPath) {
	die("usage: jj-workspace-repo-link <workspace-root> <repo-path>")
}

const linkPath = resolve(workspaceRoot, ".jj/repo")
const storedPath = relative(dirname(linkPath), resolve(repoPath))
	.split("\\")
	.join("/")
const temporaryPath = `${linkPath}.tmp.${process.pid}`
let fileDescriptor: number | undefined

try {
	fileDescriptor = openSync(temporaryPath, "wx", 0o600)
	writeFileSync(fileDescriptor, storedPath)
	fsyncSync(fileDescriptor)
	closeSync(fileDescriptor)
	fileDescriptor = undefined
	renameSync(temporaryPath, linkPath)
} finally {
	if (fileDescriptor !== undefined) {
		closeSync(fileDescriptor)
	}
	try {
		unlinkSync(temporaryPath)
	} catch (error) {
		if (
			!(error instanceof Error) ||
			!("code" in error) ||
			error.code !== "ENOENT"
		) {
			throw error
		}
	}
}
