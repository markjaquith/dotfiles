-- Text reference — depends on LSP
vim.api.nvim_set_hl(0, 'LspReferenceText', { underdotted = true, sp = '#6e738d' })

-- A read reference to a token
vim.api.nvim_set_hl(0, 'LspReferenceRead', { underline = true, sp = '#939ab7' })

-- A write reference to a token
vim.api.nvim_set_hl(0, 'LspReferenceWrite', { undercurl = true, sp = '#a6da95' })
