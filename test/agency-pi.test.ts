import { expect, mock, test } from "bun:test"
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

test("Pi cache deduplicates and retains failed lookups", async () => {
	const root = await mkdtemp(join(tmpdir(), "agency-pi-"))
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
		await discover()
		expect(exec).toHaveBeenCalledTimes(1)
		expect(await discover()).toBeUndefined()
		expect(exec).toHaveBeenCalledTimes(1)
	} finally {
		await rm(root, { recursive: true, force: true })
	}
})
