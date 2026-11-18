-- Herdr-plugin equivalents, including Vim-aware Ctrl-H/J/K/L pane navigation
-- with the same keys used for tmux panes in Ghostty.
dofile(os.getenv("HOME") .. "/.config/rex/mux.lua").setup()
-- Switch tabs with the same keys used for tmux windows and herdr tabs.
rex.bind("alt+h", "client.tab.previous")
rex.bind("alt+l", "client.tab.next")
-- Herdr's Ctrl-B prefix bindings, e.g. Ctrl-B then X closes the pane.
dofile(os.getenv("HOME") .. "/.config/rex/prefix.lua").setup()

-- Agentodon integration is managed by `agentodon setup`.
-- BEGIN Agentodon (managed)
do
	local path = os.getenv("HOME") .. "/.config/rex/agentodon.lua"
	local file = io.open(path, "r")
	if file then
		file:close()
		dofile(os.getenv("HOME") .. "/.config/rex/agentodon-config.lua")
	end
end
-- END Agentodon (managed)
