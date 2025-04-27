-- PLUGIN: Amy's Factory Finder
-- WARNING: Only enabled if it exists on the filesystem
return {
  'apaslak/factory_finder.nvim',
  dir = '~/Dev/factory_finder.nvim',
  cond = function()
    return vim.fn.isdirectory(vim.fn.expand '~/Dev/factory_finder.nvim') == 1
  end,
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  config = function()
    require('factory_finder').setup()
  end,
  event = 'VeryLazy',
}
