-- Herdr-plugin equivalents, including Vim-aware Ctrl-H/J/K/L pane navigation
-- with the same keys used for tmux panes in Ghostty.
dofile(os.getenv("HOME") .. "/.config/rex/mux.lua").setup()
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
