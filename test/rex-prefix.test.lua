-- Unit tests for home/.config/rex/prefix.lua with a fake rex API.
-- Run: lua test/rex-prefix.test.lua
local root = arg[0]:match("^(.*)/test/") or "."
local bindings, modes = {}, {}

rex = {
	bind = function(key, action, args)
		assert(not bindings[key], "duplicate binding: " .. key)
		bindings[key] = { action = action, args = args }
	end,
	mode = function(name, options)
		modes[name] = options
	end,
}

dofile(root .. "/home/.config/rex/prefix.lua").setup()

local count = 0
local function check(name, condition)
	count = count + 1
	if not condition then
		error("FAIL: " .. name, 2)
	end
end

for key in pairs(bindings) do
	check(key .. " is a prefix sequence or resize binding", key:find("^ctrl%+b>") or key:find("^resize/"))
end

check("close pane", bindings["ctrl+b>x"].action == "pane.close")
check("split right", bindings["ctrl+b>v"].action == "pane.split.right")
check("split down", bindings["ctrl+b>-"].action == "pane.split.down")
check("new tab here", bindings["ctrl+b>c"].action == "tab_new_here")
check("tab 1", bindings["ctrl+b>1"].action == "client.tab.goto" and bindings["ctrl+b>1"].args.index == 1)
check("tab 9", bindings["ctrl+b>9"].args.index == 9)
check("focus left", bindings["ctrl+b>h"].action == "pane.focus.left")
check("swap down", bindings["ctrl+b>shift+j"].action == "pane.move.down")
check("workspace picker", bindings["ctrl+b>w"].action == "session.switch")
check("prefix passthrough", bindings["ctrl+b>ctrl+b"].action == "pane.send_key" and bindings["ctrl+b>ctrl+b"].args.key == "ctrl+b")

check("resize mode is exclusive", modes.resize and modes.resize.exclusive == true)
check("enter resize", bindings["ctrl+b>r"].action == "client.mode.enter" and bindings["ctrl+b>r"].args.name == "resize")
check("resize h", bindings["resize/h"].action == "pane.resize" and bindings["resize/h"].args.direction == "left")
check("resize arrow", bindings["resize/up"].args.direction == "up")
check("resize big step", bindings["resize/shift+l"].args.amount == 15)
check("leave resize", bindings["resize/enter"].action == "client.mode.exit")

for _, key in ipairs({ "ctrl+b>ctrl+o", "ctrl+b>o", "ctrl+b>shift+/" }) do
	check(key .. " left unbound", bindings[key] == nil)
end

print(count .. " rex prefix tests passed")
