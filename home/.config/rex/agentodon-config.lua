-- Your Agentodon settings. `agentodon setup` preserves this file.
-- Custom sidebars: https://github.com/markjaquith/agentodon/blob/main/docs/sidebars.md
local app = require("agentodon")
app.setup({
	-- keys = { toggle = "cmd+shift+b", picker = "cmd+shift+o" },
	-- Or set keys = false to register actions without binding any keys.
	-- sidebars = { app.agents(), { id = "files", title = "Files", command = { "yazi" }, focus = "retain" } },
})
