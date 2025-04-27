-- PLUGIN: This is the Neovim theme.
return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      flavour = 'macchiato', -- Set the flavor here
      -- integrations = {
      --   lualine = true, -- Integrate with Lualine
      --   telescope = true, -- Integrate with Telescope
      --   treesitter = true, -- Treesitter highlighting
      --   trouble = true, -- Integrate with Trouble
      -- },
    }
    vim.cmd.colorscheme 'catppuccin'
  end,
}
