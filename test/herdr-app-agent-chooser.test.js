import { beforeEach, describe, expect, mock, test } from "bun:test"
import { readFileSync } from "node:fs"
import {
	ChooserModel,
	counts,
	matches,
} from "../home/.config/herdr-app/mods/agent-chooser/model.js"

function agent(address, status = "idle", extra = {}) {
	return {
		address,
		status,
		seq: 0,
		space_name: "dotfiles",
		tab_name: "Keyboard shortcuts",
		title: "Implement agent chooser",
		app: "pi",
		program: { name: "Pi" },
		...extra,
	}
}

const sample = [
	agent("t1", "idle"),
	agent("t2", "working"),
	agent("remote/t3", "blocked", { seq: 4 }),
	agent("t4", "done", { seq: 8 }),
]

function addresses(model, agents = sample) {
	return model.rows(agents).map((a) => a.address)
}

describe("agent chooser model", () => {
	test("counts views and starts on the first nonempty view", () => {
		expect(counts(sample)).toEqual({ attention: 2, working: 1, all: 4 })
		expect(new ChooserModel(sample).view).toBe("attention")
		expect(new ChooserModel([sample[1]]).view).toBe("working")
		expect(new ChooserModel([sample[0]]).view).toBe("all")
		expect(new ChooserModel([]).view).toBe("all")
	})

	test("attention sorts newest first; other views preserve app order", () => {
		const model = new ChooserModel(sample)
		expect(addresses(model)).toEqual(["t4", "remote/t3"])
		model.setView("working")
		expect(addresses(model)).toEqual(["t2"])
		model.setView("all")
		expect(addresses(model)).toEqual(sample.map((a) => a.address))
		expect(sample[0].address).toBe("t1")
	})

	test("fuzzy search is case-insensitive across agent metadata", () => {
		expect(matches(sample[2], "DF KBS P IAC REM/T3 BLKD")).toBe(true)
		expect(matches(sample[2], "   ")).toBe(true)
		expect(matches(sample[2], "missing")).toBe(false)
		expect(
			matches(agent("t5", "idle", { title: "修复键盘 🐱" }), "修键 🐱"),
		).toBe(true)
		expect(matches(agent("t5", "idle", { program: null }), "pi")).toBe(true)
	})

	test("query and view changes reset selection but retain the query", () => {
		const model = new ChooserModel(sample)
		model.move(1, sample)
		expect(model.selected).toBe("remote/t3")
		model.setQuery("dotfiles")
		model.rows(sample)
		expect(model.selected).toBe("t4")
		model.setView("working")
		model.rows(sample)
		expect(model.query).toBe("dotfiles")
		expect(model.selected).toBe("t2")
	})

	test("Tab and Shift-Tab cycle all three views", () => {
		const model = new ChooserModel(sample)
		model.cycle(-1)
		expect(model.view).toBe("all")
		model.cycle(1)
		expect(model.view).toBe("attention")
		model.cycle(1)
		expect(model.view).toBe("working")
		model.cycle(1)
		expect(model.view).toBe("all")
		model.setView("invalid")
		expect(model.view).toBe("all")
	})

	test("navigation clamps at both ends and handles zero or one agent", () => {
		for (const list of [[], [sample[0]], sample]) {
			const model = new ChooserModel(list)
			model.move(-100, list)
			expect(model.index).toBe(0)
			model.move(100, list)
			expect(model.index).toBe(Math.max(0, model.rows(list).length - 1))
			expect(model.selected).toBe(
				list.length ? addresses(model, list).at(-1) : null,
			)
		}
	})

	test("keeps selection by address when live agents reorder", () => {
		const model = new ChooserModel(sample)
		model.rows(sample)
		expect(model.selected).toBe("t4")
		model.rows(
			sample.map((a) => ({
				...a,
				seq: a.address === "remote/t3" ? 99 : a.seq,
			})),
		)
		expect(model.selected).toBe("t4")
		expect(model.index).toBe(1)
	})

	test("falls back safely when selection disappears or leaves the view", () => {
		const model = new ChooserModel(sample)
		model.move(1, sample)
		model.rows(sample.filter((a) => a.address !== "remote/t3"))
		expect(model.selected).toBe("t4")
		model.rows(sample.filter((a) => a.status === "idle"))
		expect(model.selected).toBeNull()
		model.move(1, [])
		expect(model.index).toBe(0)
		model.rows([agent("t9", "done")])
		expect(model.selected).toBe("t9")
	})

	test("no matches has no selection; clearing search recovers", () => {
		const model = new ChooserModel(sample)
		model.setQuery("nothing matches")
		expect(addresses(model)).toEqual([])
		expect(model.selected).toBeNull()
		model.setQuery("")
		expect(addresses(model)).toHaveLength(2)
		expect(model.selected).toBe("t4")
	})
})

// Describe the native UI with small host stubs, and explicitly invoke deferred
// virtual-list rows: `herdr-app check` does not exercise those callbacks.
let live = []
let calls = []
let renderingRows = false
let spawnTask
let scrollCalls
let input

function element(kind) {
	const node = { kind, nodes: [], handlers: {}, attrs: {} }
	const proxy = new Proxy(node, {
		get(target, method) {
			if (method in target) return target[method]
			return (...args) => {
				if (method === "child") target.nodes.push(args[0])
				else if (method === "children") target.nodes.push(...args[0])
				else if (method === "when") {
					if (args[0]) args[1](proxy)
				} else if (method.startsWith("on_")) {
					if (renderingRows)
						throw new Error("Handlers cannot be attached in deferred rows")
					target.handlers[method] = args.at(-1)
				} else target.attrs[method] = args
				return proxy
			}
		},
	})
	return proxy
}

const cx = {
	focus_handle: () => ({ focus() {} }),
	notify: () => calls.push(["notify"]),
	stop_propagation: () => calls.push(["stop"]),
	spawn: (task) => {
		spawnTask = task
	},
}

mock.module("gpui-kit", () => ({ View: class {}, div: () => element("div") }))
mock.module("gpui-base", () => ({
	v_flex: () => element("column"),
	h_flex: () => element("row"),
	Input: { new: () => element("input") },
	InputState: {
		new: () => {
			input = {
				text: "",
				handlers: {},
				on(event, handler) {
					this.handlers[event] = handler
				},
				value() {
					return this.text
				},
				focus() {
					calls.push(["input.focus"])
				},
			}
			return input
		},
	},
	Scrollbar: { vertical: () => element("scrollbar") },
	VirtualListScrollHandle: {
		new: () => ({ scroll_to_item: (index) => scrollCalls.push(index) }),
	},
	v_virtual_list: (_id, count, _height, getKey, render) => {
		const list = element("virtual-list")
		list.count = count
		list.getKey = getKey
		list.renderRows = render
		return list
	},
}))
mock.module("herdr", () => ({
	agents: () => live,
	closeOverlay: (id) => calls.push(["close", id]),
	nextCommand: () => new Promise(() => {}),
	props: () => ({ overlay: "mod-agent-chooser" }),
	run: (name, args) => calls.push([name, args]),
	theme: () => new Proxy({}, { get: () => "#24273a" }),
}))

const { default: AgentChooser } =
	await import("../home/.config/herdr-app/mods/agent-chooser/main.js")

function find(tree, predicate) {
	if (!tree || typeof tree !== "object") return null
	if (predicate(tree)) return tree
	for (const child of tree.nodes ?? []) {
		const found = find(child, predicate)
		if (found) return found
	}
	return null
}

function start(list = sample) {
	live = list
	const view = new AgentChooser()
	view.init({}, cx)
	return view
}

describe("agent chooser native view", () => {
	beforeEach(() => {
		calls = []
		scrollCalls = []
		renderingRows = false
	})

	test("initialization focuses search and does not focus any agent", () => {
		start()
		expect(calls).toEqual([["input.focus"]])
		expect(typeof spawnTask).toBe("function")
	})

	test("deferred rows render without attaching handlers", () => {
		const view = start()
		const list = find(view.render(), (el) => el.kind === "virtual-list")
		expect(list.count).toBe(2)
		expect(list.getKey(0)).toBe("t4")
		renderingRows = true
		const rows = list.renderRows({ start: 0, end: 2 })
		expect(rows).toHaveLength(2)
		expect(rows[0].attrs.id).toEqual(["agent-t4"])
		renderingRows = false
	})

	test("navigation scrolls selection into view without focusing terminals", () => {
		const view = start()
		view.command("next", cx)
		expect(view.model.selected).toBe("remote/t3")
		expect(scrollCalls).toEqual([1])
		view.command("previous", cx)
		expect(view.model.selected).toBe("t4")
		expect(calls.some(([name]) => name === "agent.focus")).toBe(false)
	})

	test("native input changes filter results; literal j/k/? remain text", () => {
		const view = start()
		input.text = "jkl?"
		input.handlers.change({}, cx)
		expect(view.model.query).toBe("jkl?")
		expect(view.model.rows(live)).toEqual([])
		expect(() => view.render()).not.toThrow()
		view.command("choose", cx)
		expect(calls.some(([name]) => name === "agent.focus")).toBe(false)
	})

	test("view buttons change view and keep the search input focused", () => {
		const view = start()
		const tab = find(
			view.render(),
			(el) => el.attrs.id?.[0] === "agent-chooser-working",
		)
		tab.handlers.on_click({}, cx)
		expect(view.model.view).toBe("working")
		expect(calls.at(-2)).toEqual(["input.focus"])
	})

	test("Enter closes the chooser before focusing the selected agent", () => {
		const view = start()
		view.command("choose", cx)
		expect(calls.slice(-2)).toEqual([
			["close", "mod-agent-chooser"],
			["agent.focus", { terminal: "t4" }],
		])
	})

	test("mouse selection uses the captured stable address, not the row index", () => {
		const view = start()
		const list = find(view.render(), (el) => el.kind === "virtual-list")
		live = [...live].reverse()
		list.handlers.on_item_click("remote/t3", cx)
		expect(calls.at(-1)).toEqual(["agent.focus", { terminal: "remote/t3" }])
	})

	test("clicking an agent that has since exited does nothing", () => {
		const view = start()
		const list = find(view.render(), (el) => el.kind === "virtual-list")
		live = []
		list.handlers.on_item_click("t4", cx)
		expect(calls).toEqual([["input.focus"]])
	})

	test("empty lists render, navigate and submit safely", () => {
		const view = start([])
		expect(find(view.render(), (el) => el.kind === "virtual-list")).toBeNull()
		view.command("next", cx)
		view.command("previous", cx)
		view.command("choose", cx)
		expect(view.model.selected).toBeNull()
		expect(calls.some(([name]) => name === "agent.focus")).toBe(false)
	})

	test("dismissal closes only this overlay and never touches a terminal", () => {
		const view = start()
		view.command("dismiss", cx)
		expect(calls.at(-1)).toEqual(["close", "mod-agent-chooser"])
		expect(calls.some(([name]) => name === "agent.focus")).toBe(false)
	})

	test("raw keys outside the input provide the same controls", () => {
		const view = start()
		const root = view.render()
		root.handlers.on_key_down({ keystroke: "ctrl-n" }, cx)
		expect(view.model.selected).toBe("remote/t3")
		root.handlers.on_key_down({ keystroke: "tab" }, cx)
		expect(view.model.view).toBe("working")
		const query = view.model.query
		root.handlers.on_key_down({ keystroke: "j" }, cx)
		expect(view.model.query).toBe(query)
	})
})

test("Cmd-O and input bindings are scoped; Ghostty/Herdr remain independent", () => {
	const root = new URL("../", import.meta.url)
	const keys = JSON.parse(
		readFileSync(new URL("home/.config/herdr-app/keys.json", root), "utf8"),
	)
	expect(keys.global["cmd-o"]).toBe("mod.open:agent-chooser")
	expect(keys.global["ctrl-k"]).toBe("pane.go:up")
	expect(keys.global["alt-l"]).toBe("tab.next")
	const inputKeys = keys["mod:agent-chooser > Input"]
	expect(inputKeys.down).toBe("agent-chooser.next")
	expect(inputKeys["ctrl-n"]).toBe(inputKeys.down)
	expect(inputKeys.up).toBe("agent-chooser.previous")
	expect(inputKeys["ctrl-p"]).toBe(inputKeys.up)
	expect(inputKeys.tab).toBe("agent-chooser.next-view")
	expect(inputKeys["shift-tab"]).toBe("agent-chooser.previous-view")
	expect(inputKeys.enter).toBe("agent-chooser.choose")
	expect(inputKeys.escape).toBe("agent-chooser.dismiss")
	expect(
		readFileSync(new URL("home/.config/ghostty/config", root), "utf8"),
	).toContain("keybind = super+o=text:\\x02\\x0f")
	expect(
		readFileSync(new URL("home/.config/herdr/config.toml", root), "utf8"),
	).toContain('command = "agent-chooser.open"')
})
