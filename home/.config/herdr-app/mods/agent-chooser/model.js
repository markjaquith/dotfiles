export const VIEWS = ["attention", "working", "all"]

export function inView(agent, view) {
	if (view === "attention") {
		return agent.status === "blocked" || agent.status === "done"
	}
	return view === "all" || agent.status === "working"
}

export function counts(agents) {
	return Object.fromEntries(
		VIEWS.map((view) => [view, agents.filter((a) => inView(a, view)).length]),
	)
}

// Like the existing fzf chooser: case-insensitive, ordered fuzzy characters.
export function matches(agent, query) {
	const text = [
		agent.space_name,
		agent.tab_name,
		agent.program?.name,
		agent.title,
		agent.app,
		agent.address,
		agent.status,
	]
		.join(" ")
		.toLowerCase()
	return query
		.toLowerCase()
		.trim()
		.split(/\s+/)
		.every((word) => {
			let at = 0
			for (const char of word) {
				const next = text.indexOf(char, at)
				if (next < 0) return false
				at = next + char.length
			}
			return true
		})
}

export class ChooserModel {
	constructor(agents) {
		const totals = counts(agents)
		this.view = totals.attention
			? "attention"
			: totals.working
				? "working"
				: "all"
		this.query = ""
		this.selected = null
		this.index = 0
	}

	rows(agents) {
		const rows = agents.filter(
			(agent) => inView(agent, this.view) && matches(agent, this.query),
		)
		if (this.view === "attention") {
			rows.sort((a, b) => (b.seq ?? 0) - (a.seq ?? 0))
		}
		const found = rows.findIndex((agent) => agent.address === this.selected)
		this.index = found < 0 ? Math.min(this.index, rows.length - 1) : found
		this.index = Math.max(0, this.index)
		this.selected = rows[this.index]?.address ?? null
		return rows
	}

	move(delta, agents) {
		const rows = this.rows(agents)
		this.index = Math.max(0, Math.min(rows.length - 1, this.index + delta))
		this.selected = rows[this.index]?.address ?? null
	}

	setView(view) {
		if (!VIEWS.includes(view)) return
		this.view = view
		this.selected = null
		this.index = 0
	}

	cycle(delta) {
		const index =
			(VIEWS.indexOf(this.view) + delta + VIEWS.length) % VIEWS.length
		this.setView(VIEWS[index])
	}

	setQuery(query) {
		this.query = query
		this.selected = null
		this.index = 0
	}
}
