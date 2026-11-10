-- Unit tests for home/.config/rex/mux.lua with a fake rex API.
-- Run: lua test/rex-mux.test.lua
local root = arg[0]:match("^(.*)/test/") or "."
local calls, actions, bindings = {}, {}, {}
local processes = {}
local view = { windows = {} }

local function record(name)
	return function(args)
		calls[#calls + 1] = { name = name, args = args }
		return { ok = name }
	end
end

rex = {
	action = function(spec)
		actions[spec.name] = spec
	end,
	bind = function(key, action, args)
		bindings[key] = { action = action, args = args }
	end,
	layout = {
		block = function(spec)
			return { block = spec }
		end,
	},
	session = {
		new_window = record("new_window"),
		new_layer = record("new_layer"),
		focus_direction = record("focus_direction"),
		view = function()
			return view
		end,
		describe_block = function(args)
			return { block = { window_id = "window:of-" .. args.block_id } }
		end,
	},
	block = {
		call = function(creator, method, args)
			assert(creator == "com.superlogical.terminal", creator)
			if method == "process" then
				return { foreground = processes[args.block_id] }
			end
			calls[#calls + 1] = { name = method, args = args }
			return { bytes_written = #args.data }
		end,
	},
}

local mux = dofile(root .. "/home/.config/rex/mux.lua")
mux.setup()

local count = 0
local function check(name, condition)
	count = count + 1
	if not condition then
		error("FAIL: " .. name, 2)
	end
end
local function reset()
	calls = {}
end

for _, name in ipairs({ "nvim", "vim", "vi", "view", "gvim", "vimdiff", "nvimdiff", "NVIM", "herdr" }) do
	check(name .. " forwards", mux.forwards(name))
end
for _, name in ipairs({ "zsh", "opencode", "pi", "vimrc", "", nil }) do
	check(tostring(name) .. " does not forward", not mux.forwards(name))
end

check("ctrl+h bound", bindings["ctrl+h"].action == "nav" and bindings["ctrl+h"].args.direction == "left")
check("ctrl+l bound", bindings["ctrl+l"].args.direction == "right")
check("new tab bindings", bindings["shift+cmd+t"].action == "tab_new_here" and bindings["ctrl+cmd+t"].action == "tab_new_first")
check("url binding", bindings["ctrl+cmd+u"].action == "url_choose")

local ctx = { session_id = "session:s", block_id = "block:b" }

processes["block:b"] = { name = "nvim", cwd = "/work" }
reset()
actions.nav.run(ctx, { direction = "down" })
check("vim gets ctrl+j bytes", #calls == 1 and calls[1].name == "write" and calls[1].args.data == "\10" and calls[1].args.block_id == "block:b")

processes["block:b"] = { name = "zsh", cwd = "/work" }
reset()
actions.nav.run(ctx, { direction = "left" })
check("shell moves focus", #calls == 1 and calls[1].name == "focus_direction" and calls[1].args.direction == "left" and calls[1].args.session_id == "session:s")
check("bad direction errors", not pcall(actions.nav.run, ctx, { direction = "sideways" }))

reset()
actions.tab_new_here.run(ctx)
check("new tab here uses focused cwd", calls[1].name == "new_window" and calls[1].args.focus == true and calls[1].args.layout.block.options.cwd == "/work")

view = {
	windows = {
		{ layers = { { blocks = { { block_id = "block:sidebar" }, { block_id = "block:first" } } } } },
		{ layers = { { blocks = { { block_id = "block:later" } } } } },
	},
}
processes["block:sidebar"] = { name = "login" }
processes["block:first"] = { name = "zsh", cwd = "/first" }
processes["block:later"] = { name = "zsh", cwd = "/later" }
reset()
actions.tab_new_first.run(ctx)
check("new tab first skips panes without a cwd", calls[1].args.layout.block.options.cwd == "/first")

reset()
actions.url_choose.run(ctx)
local layer = calls[1].args
check("url chooser floats over the pane's tab", calls[1].name == "new_layer" and layer.window_id == "window:of-block:b" and layer.focus == true)
local command = layer.layout.block.options.command
check("url chooser targets the pane", command[1]:match("/dotfiles/bin/rex%-url%-chooser$") and command[2] == "session:s" and command[3] == "block:b")

print(count .. " rex mux tests passed")
