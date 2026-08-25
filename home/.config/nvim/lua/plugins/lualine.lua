-- PLUGIN: Lualine is a performant and flexible status line plugin
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local trouble = {
      sections = {
        lualine_a = {},
        lualine_b = {
          function()
            return 'Trouble'
          end,
        },
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      filetypes = { 'trouble' },
    }
    require('lualine').setup {
      options = {
        theme = 'catppuccin-macchiato',
        component_separators = '',
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = { { 'mode', separator = { left = '' }, right_padding = 2 } },
        lualine_b = { 'filename', { 'branch', icon = '' } },
        lualine_c = {
          '%=', --[[ add center components here ]]
        },
        lualine_x = {},
        lualine_y = { 'filetype', 'progress' },
        lualine_z = {
          { 'location', separator = { right = '' }, left_padding = 2 },
        },
      },
      inactive_sections = {
        lualine_a = { 'filename' },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      extensions = {
        'lazy',
        'fzf',
        'man',
        'nvim-tree',
        'oil',
        trouble,
      },
    }
  end,
}
