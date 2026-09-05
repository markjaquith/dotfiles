import { expect, mock, spyOn, test } from "bun:test"
import { existsSync } from "node:fs"
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { homedir, tmpdir } from "node:os"
import { join } from "node:path"
import agencyExtension from "../home/.pi/agent/extensions/agency"

const source = join(
	process.env.AGENCY_SOURCE_DIR ?? join(homedir(), "Dev", "agency"),
	"pi-extensions",
	"agency.ts",
)

test.skipIf(!existsSync(source))(
	"Pi extension is byte-identical to Agency source",
	async () => {
		expect(
			await readFile(
				join(import.meta.dir, "../home/.pi/agent/extensions/agency.ts"),
			),
		).toEqual(await readFile(source))
	},
)

test("Pi cache deduplicates, retries failures, and refreshes on reload and TTL", async () => {
	const root = await mkdtemp(join(tmpdir(), "agency-pi-"))
	let now = 0
	const clock = spyOn(Date, "now").mockImplementation(() => now)
	try {
		await writeFile(join(root, "agency.json"), '{"version":2}\n')
		const checkout = join(root, "checkout")
		const skills = join(checkout, ".agents", "skills")
		await mkdir(skills, { recursive: true })
		const pending = Promise.withResolvers<{ code: number; stdout: string }>()
		const exec = mock(() => pending.promise)
		const handlers = new Map<string, (...args: any[]) => any>()
		agencyExtension({
			exec,
			on: (name, handler) => {
				handlers.set(name, handler)
			},
		})
		const discover = () =>
			handlers.get("resources_discover")!({ cwd: root, reason: "startup" })
		const prompt = () =>
			handlers.get("before_agent_start")!(
				{ systemPrompt: "Base" },
				{ cwd: root },
			)
		const resources = discover()
		const before = prompt()
		expect(exec).toHaveBeenCalledTimes(1)
		pending.reject(new Error("temporary failure"))
		await Promise.all([resources, before])
		now = 999
		await discover()
		expect(exec).toHaveBeenCalledTimes(1)
		exec.mockResolvedValue({
			code: 0,
			stdout: JSON.stringify({
				ok: true,
				result: {
					workbase: { root },
					target: { kind: "task", taskId: "example" },
					authority: {
						mode: "execution",
						writable: { checkoutPath: checkout },
					},
					documents: { task: { data: { status: "working" } } },
					validation: { valid: true },
				},
			}),
		})
		now = 1000
		expect((await discover()).skillPaths).toEqual([skills])
		expect((await prompt()).systemPrompt).toContain(checkout)
		expect(exec).toHaveBeenCalledTimes(2)
		await handlers.get("session_start")!({
			type: "session_start",
			reason: "reload",
		})
		await discover()
		await prompt()
		expect(exec).toHaveBeenCalledTimes(3)
		now += 60_000
		exec.mockResolvedValue({ code: 1, stdout: "" })
		expect(await discover()).toBeUndefined()
		expect(exec).toHaveBeenCalledTimes(4)
	} finally {
		clock.mockRestore()
		await rm(root, { recursive: true, force: true })
	}
})
