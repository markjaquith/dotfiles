-- PLUGIN: Tabby manages Neovim tabs and the tabline
return {
  'nanozuki/tabby.nvim',
  -- event = 'VimEnter', -- if you want lazy load, see below
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = function()
    local ctp = require('catppuccin.palettes').get_palette 'macchiato'

    local theme = {
      fill = 'TabLineFill',
      head = { fg = ctp.blue, bg = ctp.base },
      current_tab = { fg = ctp.crust, bg = ctp.blue },
      tab = { fg = ctp.blue, bg = ctp.base, style = 'italic' },
      win = { fg = ctp.crust, bg = ctp.blue },
      tail = { fg = ctp.blue, bg = ctp.base },
    }

    require('tabby.tabline').set(function(line)
      return {
        {
          { '🖥️', hl = theme.head },
          line.sep('', theme.head, theme.fill), -- 
        },
        line.tabs().foreach(function(tab)
          local hl = tab.is_current() and theme.current_tab or theme.tab

          -- Filter NvimTree buffers when getting tab name
          local function tab_name()
            local wins = vim.api.nvim_tabpage_list_wins(tab.id)
            for _, win in ipairs(wins) do
              local buf = vim.api.nvim_win_get_buf(win)
              local buf_ft = vim.bo[buf].filetype
              if buf_ft ~= 'NvimTree' then
                return tab.name()
              end
            end
            return '[No Name]' -- Fallback if NvimTree exists
          end

          return {
            line.sep('', hl, theme.fill), -- 
            -- tab.is_current() and '' or '',
            tab.number(),
            tab_name(),
            -- tab.close_btn(''), -- show a close button
            line.sep('', hl, theme.fill), -- 
            hl = hl,
            margin = ' ',
          }
        end),

        line.spacer(),
        line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
          return {
            line.sep('', theme.win, theme.fill),
            win.is_current() and '' or '',
            win.buf_name(),
            line.sep('', theme.win, theme.fill),
            hl = theme.win,
            margin = ' ',
          }
        end),
        -- {
        --   line.sep('', theme.tail, theme.fill), -- 
        --   { '  ', hl = theme.tail },
        -- },
        hl = theme.fill,
      }
    end)
  end,
}
