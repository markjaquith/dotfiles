import { expect, mock, test } from "bun:test"
import { createHash } from "node:crypto"
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import agencyExtension from "../home/.pi/agent/extensions/agency"

// The vendored file comes from pi-extensions/agency.ts in markjaquith/agency.
// When updating it, use a specific Agency commit and calculate the pin from
// the upstream bytes: git -C ~/Dev/agency show <rev>:pi-extensions/agency.ts | shasum -a 256
const agencyRevision = "0d06b382c0c45539d029a1e8f7de83d054a6794e"
const agencyExtensionSha256 =
	"88d40cd67f419e905c79e7958f19f637f65fe23f76d8c440ef9ad5b991a75a5f"

test(`Pi extension matches pinned Agency revision ${agencyRevision}`, async () => {
	const vendored = await readFile(
		join(import.meta.dir, "../home/.pi/agent/extensions/agency.ts"),
	)
	expect(createHash("sha256").update(vendored).digest("hex")).toBe(
		agencyExtensionSha256,
	)
})

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
