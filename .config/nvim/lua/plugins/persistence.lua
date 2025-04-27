-- PLUGIN: Session saving
return {
  'folke/persistence.nvim',
  event = 'BufReadPre', -- this will only start session saving when an actual file was opened
  opts = {},
  init = function()
    vim.opt.sessionoptions = { 'buffers', 'curdir', 'folds', 'help', 'localoptions', 'winpos', 'winsize', 'tabpages' }
  end,
  keys = {
    -- Session management
    { '<leader>Sl', function() require('persistence').load() end,   { desc = '[S]ession [L]oad', } },
    { '<leader>Ss', function() require('persistence').select() end, { desc = '[S]ession [S]elect' } },
    { '<leader>Sd', function() require('persistence').stop() end,   { desc = '[S]ession [D]elete' } },
  },
}
