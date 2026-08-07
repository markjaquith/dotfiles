#!/usr/bin/env bun

import {
	closeSync,
	fsyncSync,
	openSync,
	readFileSync,
	renameSync,
	unlinkSync,
	writeFileSync,
} from "node:fs"
import { dirname, normalize, relative, resolve } from "node:path"

type Field = {
	fieldNumber: number
	wireType: number
	start: number
	end: number
	payloadStart?: number
	payloadEnd?: number
}

function die(message: string): never {
	console.error(`jj-workspace-store-path: ${message}`)
	process.exit(1)
}

function readVarint(buffer: Buffer, offset: number): [number, number] {
	let value = 0
	let shift = 0

	for (let index = offset; index < buffer.length && shift <= 49; index++) {
		const byte = buffer[index]
		if (byte === undefined) {
			break
		}
		value += (byte & 0x7f) * 2 ** shift
		if ((byte & 0x80) === 0) {
			return [value, index + 1]
		}
		shift += 7
	}

	die("invalid protobuf varint")
}

function encodeVarint(value: number): Buffer {
	if (!Number.isSafeInteger(value) || value < 0) {
		die(`cannot encode protobuf varint: ${value}`)
	}

	const bytes: number[] = []
	do {
		let byte = value % 128
		value = Math.floor(value / 128)
		if (value > 0) {
			byte |= 0x80
		}
		bytes.push(byte)
	} while (value > 0)

	return Buffer.from(bytes)
}

function parseFields(buffer: Buffer): Field[] {
	const fields: Field[] = []
	let offset = 0

	while (offset < buffer.length) {
		const start = offset
		const [tag, afterTag] = readVarint(buffer, offset)
		const fieldNumber = Math.floor(tag / 8)
		const wireType = tag % 8
		offset = afterTag

		if (fieldNumber === 0) {
			die("invalid protobuf field number 0")
		}

		switch (wireType) {
			case 0: {
				const [, end] = readVarint(buffer, offset)
				fields.push({ fieldNumber, wireType, start, end })
				offset = end
				break
			}
			case 1: {
				const end = offset + 8
				if (end > buffer.length) {
					die("truncated protobuf fixed64 field")
				}
				fields.push({ fieldNumber, wireType, start, end })
				offset = end
				break
			}
			case 2: {
				const [length, payloadStart] = readVarint(buffer, offset)
				const payloadEnd = payloadStart + length
				if (payloadEnd > buffer.length) {
					die("truncated protobuf length-delimited field")
				}
				fields.push({
					fieldNumber,
					wireType,
					start,
					end: payloadEnd,
					payloadStart,
					payloadEnd,
				})
				offset = payloadEnd
				break
			}
			case 5: {
				const end = offset + 4
				if (end > buffer.length) {
					die("truncated protobuf fixed32 field")
				}
				fields.push({ fieldNumber, wireType, start, end })
				offset = end
				break
			}
			default:
				die(`unsupported protobuf wire type ${wireType}`)
		}
	}

	return fields
}

function payload(buffer: Buffer, field: Field): Buffer {
	if (field.payloadStart === undefined || field.payloadEnd === undefined) {
		die("expected a length-delimited protobuf field")
	}
	return buffer.subarray(field.payloadStart, field.payloadEnd)
}

function encodeBytesField(fieldNumber: number, value: Buffer): Buffer {
	return Buffer.concat([
		encodeVarint(fieldNumber * 8 + 2),
		encodeVarint(value.length),
		value,
	])
}

function storedPath(repoPath: string, workspaceRoot: string): string {
	const path = relative(resolve(repoPath), resolve(workspaceRoot))
	return path === "" ? "." : path.split("\\").join("/")
}

function updateWorkspace(
	message: Buffer,
	workspaceName: string,
	expectedPath: string,
	newPath: string,
): Buffer | null {
	const fields = parseFields(message)
	const nameFields = fields.filter(
		(field) => field.fieldNumber === 1 && field.wireType === 2,
	)
	if (nameFields.length !== 1) {
		die("workspace entry does not have exactly one name field")
	}
	if (payload(message, nameFields[0]!).toString("utf8") !== workspaceName) {
		return null
	}

	const pathFields = fields.filter(
		(field) => field.fieldNumber === 2 && field.wireType === 2,
	)
	if (pathFields.length !== 1) {
		die(`workspace '${workspaceName}' does not have exactly one path field`)
	}

	const pathField = pathFields[0]!
	const currentPath = payload(message, pathField).toString("utf8")
	if (normalize(currentPath) === normalize(newPath)) {
		return message
	}
	if (normalize(currentPath) !== normalize(expectedPath)) {
		die(
			`workspace '${workspaceName}' path is '${currentPath}', expected '${expectedPath}'`,
		)
	}

	return Buffer.concat([
		message.subarray(0, pathField.start),
		encodeBytesField(2, Buffer.from(newPath)),
		message.subarray(pathField.end),
	])
}

function main(): void {
	const [indexPath, repoPath, workspaceName, oldRoot, newRoot] =
		process.argv.slice(2)
	if (!indexPath || !repoPath || !workspaceName || !oldRoot || !newRoot) {
		die(
			"usage: jj-workspace-store-path <index> <repo-path> <workspace> <old-root> <new-root>",
		)
	}

	const input = readFileSync(indexPath)
	const expectedPath = storedPath(repoPath, oldRoot)
	const newPath = storedPath(repoPath, newRoot)
	const chunks: Buffer[] = []
	let matches = 0

	for (const field of parseFields(input)) {
		if (field.fieldNumber !== 1 || field.wireType !== 2) {
			chunks.push(input.subarray(field.start, field.end))
			continue
		}

		const message = payload(input, field)
		const updated = updateWorkspace(
			message,
			workspaceName,
			expectedPath,
			newPath,
		)
		if (updated === null) {
			chunks.push(input.subarray(field.start, field.end))
			continue
		}

		matches++
		chunks.push(encodeBytesField(1, updated))
	}

	if (matches !== 1) {
		die(`expected one workspace named '${workspaceName}', found ${matches}`)
	}

	const output = Buffer.concat(chunks)
	const temporaryPath = `${dirname(indexPath)}/.index.${process.pid}.tmp`
	let fileDescriptor: number | undefined
	try {
		fileDescriptor = openSync(temporaryPath, "wx", 0o600)
		writeFileSync(fileDescriptor, output)
		fsyncSync(fileDescriptor)
		closeSync(fileDescriptor)
		fileDescriptor = undefined
		renameSync(temporaryPath, indexPath)
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
}

main()
