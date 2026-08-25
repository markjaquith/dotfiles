-- Visualize whitespace
vim.opt_local.list = true
vim.opt_local.listchars = {
  tab = "→ ",
  trail = "·",
  lead = "·",
}

-- Enforce indentation
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.cmd("retab")

-- Highlight literal tab characters (shouldn't exist in YAML)
vim.api.nvim_buf_clear_namespace(0, -1, 0, -1) -- clear any old highlights
vim.fn.matchadd("ErrorMsg", [[\t]])            -- highlight tabs as errors

vim.schedule(function()
  vim.opt_local.expandtab = true
  vim.opt_local.shiftwidth = 2
  vim.opt_local.softtabstop = 2
end)
