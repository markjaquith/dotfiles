import { View, div } from "gpui-kit"
import {
	v_flex,
	h_flex,
	Input,
	InputState,
	Scrollbar,
	VirtualListScrollHandle,
	v_virtual_list,
} from "gpui-base"
import { agents, closeOverlay, nextCommand, props, run, theme } from "herdr"
import { ChooserModel, counts, VIEWS } from "./model.js"

const LABELS = { attention: "Attention", working: "Working", all: "All" }
const STATUS = {
	blocked: "Needs you",
	done: "Done",
	working: "Working",
	idle: "Idle",
}
const KEYS = {
	down: "next",
	"ctrl-n": "next",
	up: "previous",
	"ctrl-p": "previous",
	tab: "next-view",
	"shift-tab": "previous-view",
	enter: "choose",
	escape: "dismiss",
	"ctrl-c": "dismiss",
}

export default class AgentChooser extends View {
	init(_props, cx) {
		this.model = new ChooserModel(agents())
		this.scroll = VirtualListScrollHandle.new()
		this.handle = cx.focus_handle()
		this.input = InputState.new({
			placeholder: "Search agents, spaces or tabs…",
		})
		this.input.on("change", (_event, cx) => {
			this.model.setQuery(this.input.value())
			this.scroll.scroll_to_item(0)
			cx.notify()
		})
		this.input.on("submit", () => this.choose())
		this.input.focus()
		cx.spawn(async (cx) => {
			for (;;) {
				const command = await nextCommand()
				this.command(command, cx)
			}
		})
	}

	dismiss() {
		closeOverlay(props().overlay)
	}

	choose(address) {
		const live = agents()
		this.model.rows(live)
		const target = address ?? this.model.selected
		// A click may have been queued just before an agent exited.
		if (!live.some((agent) => agent.address === target)) return
		this.dismiss()
		run("agent.focus", { terminal: target })
	}

	command(command, cx) {
		if (command === "dismiss") return this.dismiss()
		if (command === "choose") return this.choose()
		if (command === "next" || command === "previous") {
			this.model.move(command === "next" ? 1 : -1, agents())
		} else if (command === "next-view" || command === "previous-view") {
			this.model.cycle(command === "next-view" ? 1 : -1)
		} else return
		this.model.rows(agents())
		if (this.model.selected) this.scroll.scroll_to_item(this.model.index)
		cx.notify()
	}

	setView(view, cx) {
		this.model.setView(view)
		this.scroll.scroll_to_item(0)
		this.input.focus()
		cx.notify()
	}

	row(agent, colors) {
		const selected = agent.address === this.model.selected
		const status = STATUS[agent.status] ?? "Unknown"
		const detail = [agent.program?.name ?? agent.app ?? "Agent", agent.title]
			.filter(Boolean)
			.join(" · ")
		return h_flex()
			.id(`agent-${agent.address}`)
			.role("list_item")
			.h(54)
			.px(10)
			.gap(10)
			.items_center()
			.rounded(7)
			.cursor_pointer()
			.bg(selected ? colors.selected : colors.popover)
			.hover((el) => el.bg(colors.hover))
			.child(
				div()
					.w(14)
					.flex_none()
					.text_color(colors[agent.status] ?? colors.dim)
					.child(selected ? "›" : agent.status === "idle" ? "○" : "●"),
			)
			.child(
				v_flex()
					.flex_1()
					.min_w(0)
					.gap(3)
					.child(
						div()
							.truncate()
							.font_semibold()
							.text_color(colors.foreground)
							.child(`${agent.space_name} · ${agent.tab_name}`),
					)
					.child(
						div()
							.truncate()
							.text_size(11)
							.text_color(colors.muted)
							.child(detail),
					),
			)
			.child(
				v_flex()
					.flex_none()
					.items_end()
					.gap(3)
					.text_size(11)
					.child(
						div()
							.text_color(colors[agent.status] ?? colors.dim)
							.child(status),
					)
					.child(div().text_color(colors.dim).child(agent.address)),
			)
	}

	render() {
		const colors = theme()
		const live = agents()
		const rows = this.model.rows(live)
		const totals = counts(live)
		return v_flex()
			.id("agent-chooser")
			.track_focus(this.handle)
			.w_full()
			.h(200 + 54 * Math.min(Math.max(rows.length, 1), 8))
			.min_h(0)
			.p(16)
			.gap(12)
			.bg(colors.popover)
			.text_size(13)
			.on_key_down((event, cx) => {
				const command = KEYS[event.keystroke]
				if (!command) return
				cx.stop_propagation()
				this.command(command, cx)
			})
			.child(
				h_flex()
					.flex_none()
					.items_center()
					.child(
						div()
							.flex_1()
							.text_size(16)
							.font_semibold()
							.text_color(colors.foreground)
							.child("Agents"),
					)
					.child(
						div()
							.id("agent-chooser-close")
							.px(6)
							.py(4)
							.cursor_pointer()
							.text_size(11)
							.text_color(colors.muted)
							.hover((el) => el.text_color(colors.foreground))
							.on_click(() => this.dismiss())
							.child("Esc · Close"),
					),
			)
			.child(
				h_flex()
					.flex_none()
					.gap(6)
					.children(
						VIEWS.map((view) =>
							div()
								.id(`agent-chooser-${view}`)
								.px(12)
								.py(6)
								.rounded(6)
								.cursor_pointer()
								.bg(this.model.view === view ? colors.selected : colors.popover)
								.text_color(
									this.model.view === view ? colors.foreground : colors.muted,
								)
								.hover((el) => el.bg(colors.hover))
								.on_click((_event, cx) => this.setView(view, cx))
								.child(`${LABELS[view]}  ${totals[view]}`),
						),
					),
			)
			.child(
				h_flex()
					.flex_none()
					.h(36)
					.px(10)
					.rounded(7)
					.border_1()
					.border_color(colors.accent)
					.bg(colors.background)
					.child(
						Input.new(this.input)
							.flex_1()
							.h_full()
							.text_color(colors.foreground),
					),
			)
			.child(
				v_flex()
					.id("agent-chooser-results")
					.relative()
					.flex_1()
					.min_h(0)
					.when(rows.length > 0, (el) =>
						el
							.child(
								v_virtual_list(
									"agent-chooser-list",
									rows.length,
									54,
									(index) => rows[index].address,
									(range) =>
										rows
											.slice(range.start, range.end)
											.map((agent) => this.row(agent, colors)),
								)
									.size_full()
									.track_scroll(this.scroll)
									.on_item_click((key) => this.choose(key)),
							)
							.child(
								Scrollbar.vertical("agent-chooser-list").absolute().inset_0(),
							),
					)
					.when(rows.length === 0, (el) =>
						el
							.items_center()
							.justify_center()
							.text_color(colors.muted)
							.child(
								this.model.query
									? "No matching agents"
									: this.model.view === "attention"
										? "No agents need your attention"
										: this.model.view === "working"
											? "No agents are working"
											: "No agents running",
							),
					),
			)
			.child(
				div()
					.flex_none()
					.text_size(11)
					.text_color(colors.dim)
					.child(
						"↑/↓ or Ctrl-N/P · select    Tab/Shift-Tab · view    Enter · go    ⌘O/Esc · close",
					),
			)
	}
}
