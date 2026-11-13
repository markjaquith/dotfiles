-- Herdr-plugin equivalents for Rex: new tabs in a pane's directory, a URL
-- chooser, and Vim-aware Ctrl-H/J/K/L. Loaded from init.lua.
local M = {}

local terminal = "com.superlogical.terminal"
local shell = "com.superlogical.terminal.shell"
local dotfiles_bin = os.getenv("HOME") .. "/dotfiles/bin"

local function foreground(block_id)
	local info = rex.block.call(terminal, "process", { block_id = block_id })
	return info and info.foreground or {}
end

-- vim-herdr-navigation's ^g?(view|l?n?vim?x?)(diff)?$, plus Herdr, so that a
-- Herdr running inside a Rex pane receives the keys too.
local function forwards(name)
	name = string.lower(name or "")
	if name == "herdr" then
		return true
	end
	name = string.gsub(string.gsub(name, "^g", ""), "diff$", "")
	return name == "view" or string.find(name, "^l?n?vim?x?$") ~= nil
end

local function new_tab(ctx, cwd)
	local options = {}
	if cwd and cwd ~= "" then
		options.cwd = cwd
	end
	local result = rex.session.new_window({
		session_id = ctx.session_id,
		focus = true,
		layout = rex.layout.block({ flavor = shell, options = options }),
	})
	-- focus only makes it the session's active window; the client keeps showing
	-- its current tab until asked to switch, as Cmd-T does.
	if result and result.window_id then
		rex.client.queue("session.select", {
			session_id = ctx.session_id,
			window_id = result.window_id,
		})
	end
	return result
end

-- The first pane in the session's first tab that reports a directory, which
-- skips sidebars such as Agentodon's.
local function first_cwd(ctx)
	local view = rex.session.view({ session_id = ctx.session_id })
	for _, window in ipairs(view and view.windows or {}) do
		for _, layer in ipairs(window.layers or {}) do
			for _, block in ipairs(layer.blocks or {}) do
				local cwd = foreground(block.block_id).cwd
				if cwd then
					return cwd
				end
			end
		end
	end
end

function M.setup()
	rex.action({
		name = "tab_new_here",
		title = "New Tab from Focused Pane Directory",
		category = "Tabs",
		run = function(ctx)
			return new_tab(ctx, ctx.block_id and foreground(ctx.block_id).cwd)
		end,
	})

	rex.action({
		name = "tab_new_first",
		title = "New Tab from First Pane Directory",
		category = "Tabs",
		run = function(ctx)
			return new_tab(ctx, first_cwd(ctx))
		end,
	})

	rex.action({
		name = "url_choose",
		title = "Choose URL from Focused Pane",
		category = "Panes",
		run = function(ctx)
			assert(ctx.block_id, "no focused pane")
			local block = rex.session.describe_block({
				session_id = ctx.session_id,
				block_id = ctx.block_id,
			})
			return rex.session.new_layer({
				session_id = ctx.session_id,
				window_id = block and block.block and block.block.window_id,
				focus = true,
				bounds = { 0.1, 0.1, 0.8, 0.8 },
				layout = rex.layout.block({
					flavor = shell,
					options = {
						command = { dotfiles_bin .. "/rex-url-chooser", ctx.session_id, ctx.block_id },
					},
				}),
			})
		end,
	})

	rex.action({
		name = "nav",
		title = "Navigate Pane (Vim-aware)",
		category = "Panes",
		args = { direction = "string" },
		run = function(ctx, args)
			-- The bytes Ctrl-H/J/K/L send; Vim and Herdr read them as those keys.
			local bytes = { left = "\8", down = "\10", up = "\11", right = "\12" }
			local data = assert(bytes[args.direction], "direction must be left, down, up, or right")
			if ctx.block_id and forwards(foreground(ctx.block_id).name) then
				return rex.block.call(terminal, "write", { block_id = ctx.block_id, data = data })
			end
			return rex.session.focus_direction({
				session_id = ctx.session_id,
				direction = args.direction,
			})
		end,
	})

	rex.bind("shift+cmd+t", "tab_new_here")
	rex.bind("ctrl+cmd+t", "tab_new_first")
	rex.bind("ctrl+cmd+u", "url_choose")
	rex.bind("ctrl+h", "nav", { direction = "left" })
	rex.bind("ctrl+j", "nav", { direction = "down" })
	rex.bind("ctrl+k", "nav", { direction = "up" })
	rex.bind("ctrl+l", "nav", { direction = "right" })
end

M.forwards = forwards
return M
