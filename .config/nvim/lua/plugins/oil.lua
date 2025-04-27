-- PLUGIN: Oil is like an editable FS you can use to rename, delete, or create files/dirs.

local is_default_file_explorer = true

return {
  'stevearc/oil.nvim',
  config = function()
    local oil = require 'oil'

    oil.setup {
      default_file_explorer = is_default_file_explorer,
      keymaps = {
        ['<C-h>'] = false,
      },
      view_options = {
        show_hidden = true,
      },
    }
  end,
  keys = {
    {
      '<leader>O',
      function()
        require('oil').toggle_float()
      end,
      { desc = 'Open [O]il' },
    },
  },
  lazy = not is_default_file_explorer,
  dependencies = { 'nvim-tree/nvim-web-devicons' },
}
