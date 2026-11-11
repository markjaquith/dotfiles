-- Herdr's Ctrl-B prefix bindings as Rex key sequences, alongside Rex's own
-- shortcuts. Herdr workspaces map to Rex sessions. Loaded from init.lua.
local M = {}

local directions = { h = "left", j = "down", k = "up", l = "right" }

local function prefix(key, action, args)
	rex.bind("ctrl+b>" .. key, action, args)
end

function M.setup()
	-- Tabs
	prefix("c", "tab_new_here")
	prefix("shift+c", "tab_new_first")
	prefix("n", "client.tab.next")
	prefix("p", "client.tab.previous")
	for index = 1, 9 do
		prefix(tostring(index), "client.tab.goto", { index = index })
	end
	prefix("shift+t", "client.tab.rename")
	prefix("shift+x", "client.tab.close")

	-- Panes
	prefix("v", "pane.split.right")
	prefix("-", "pane.split.down")
	prefix("x", "pane.close")
	prefix("z", "pane.zoom")
	for key, direction in pairs(directions) do
		prefix(key, "pane.focus." .. direction)
		prefix("shift+" .. key, "pane.move." .. direction)
	end
	prefix("tab", "pane.focus_next")
	prefix("shift+tab", "pane.focus_previous")
	prefix("shift+p", "pane.rename")

	-- Resize mode: Escape or Enter leaves.
	rex.mode("resize", { exclusive = true })
	prefix("r", "client.mode.enter", { name = "resize" })
	for key, direction in pairs(directions) do
		for _, k in ipairs({ key, direction }) do
			rex.bind("resize/" .. k, "pane.resize", { direction = direction })
			rex.bind("resize/shift+" .. k, "pane.resize", { direction = direction, amount = 15 })
		end
	end
	rex.bind("resize/=", "pane.balance")
	rex.bind("resize/enter", "client.mode.exit")

	-- Workspaces (Rex sessions)
	prefix("shift+n", "session.new")
	prefix("w", "session.switch")
	prefix("shift+w", "session.rename")
	prefix("shift+d", "session.close")
	prefix("g", "pane.go_to")

	-- Other
	prefix("b", "agents_toggle")
	prefix("shift+o", "url_choose")
	prefix("s", "client.settings")
	prefix("shift+r", "client.config.reload")
	-- Press Ctrl-B twice to send one to the terminal.
	prefix("ctrl+b", "pane.send_key", { key = "ctrl+b" })
end

return M
