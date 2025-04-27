-- PLUGIN: Trouble is for showing diagnostics.

vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  callback = function()
    vim.cmd([[Trouble qflist open]])
  end,
})

return {
  'folke/trouble.nvim',
  opts = {
    warn_no_results = false,
    open_no_results = true,
  },
  cmd = 'Trouble',
  keys = {
    {
      '<leader>tt',
      '<CMD>Trouble diagnostics toggle<CR>',
      desc = 'Diagnostics (Trouble)',
    },
    {
      '<leader>tT',
      '<CMD>Trouble diagnostics toggle filter.buf=0<CR>',
      desc = 'Buffer Diagnostics (Trouble)',
    },
    {
      '<leader>cs',
      '<CMD>Trouble symbols toggle focus=true<CR>',
      desc = 'Symbols (Trouble)',
    },
    {
      '<leader>cl',
      '<CMD>Trouble lsp toggle focus=false win.position=right<CR>',
      desc = 'LSP Definitions / references / ... (Trouble)',
    },
    {
      '<leader>tL',
      '<CMD>Trouble loclist toggle<CR>',
      desc = 'Location List (Trouble)',
    },
    {
      '<leader>tq',
      '<CMD>Trouble qflist toggle<CR>',
      desc = 'Quickfix List (Trouble)',
    },
    {
      '<leader>q',
      '<CMD>Trouble qflist toggle<CR>',
      desc = 'Open diagnostic [Q]uickfix list',
    },
    {
      ']q',
      '<CMD>Trouble qflist next jump=true<CR>',
      desc = 'Navigate to next Quickfix item',
    },
    {
      '[q',
      '<CMD>Trouble qflist prev jump=true<CR>',
      desc = 'Navigate to previous Quickfix item',
    },
  },
}
