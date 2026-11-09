-- Navigate Rex panes with the same keys used for tmux panes in Ghostty.
rex.bind("ctrl+h", "pane.focus", { direction = "left" })
rex.bind("ctrl+j", "pane.focus", { direction = "down" })
rex.bind("ctrl+k", "pane.focus", { direction = "up" })
rex.bind("ctrl+l", "pane.focus", { direction = "right" })
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
