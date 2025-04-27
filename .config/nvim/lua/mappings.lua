local M = {}

M.define_general_mappings = function()
  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<CMD>nohlsearch<CR>')

  -- Lazygit
  vim.keymap.set('n', '<leader>lg', function()
    require('snacks').lazygit.open()
  end, { desc = 'Open [L]azy[G]it' })

  -- LSP Commands
  vim.keymap.set('n', '<leader>lr', '<CMD>LspRestart<CR>', { desc = '[L]SP [R]estart' })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Tab management
  vim.keymap.set('n', '<leader>tn', ':tabnew<CR>', { noremap = true, silent = true, desc = '[T]ab [N]ew' })            -- New tab
  vim.keymap.set('n', '<leader>tx', ':tabclose<CR>', { noremap = true, silent = true, desc = '[T]ab Close' })          -- Close tab
  vim.keymap.set('n', '<leader>to', ':tabonly<CR>', { noremap = true, silent = true, desc = '[T]ab Only' })            -- Close other tabs
  vim.keymap.set('n', '<leader>tr', ':Tabby rename_tab ', { noremap = true, silent = false, desc = '[T]ab [R]ename' }) -- Rename the current tab
  vim.keymap.set('n', '<leader>ts', ':tab split<CR>', { noremap = true, silent = true, desc = '[T]ab [S]plit' })       -- Split tab

  -- Diagnostics
  vim.keymap.set('n', '<leader>dd', vim.diagnostic.open_float, { desc = '[D]iagnostics [D]etails' })

  -- Disable arrow keys in normal mode
  vim.keymap.set('n', '<left>', '')
  vim.keymap.set('n', '<right>', '')
  vim.keymap.set('n', '<up>', '')
  vim.keymap.set('n', '<down>', '')

  -- Clever... it will exit insert mode if you type jk in succession
  vim.keymap.set('i', 'jk', '<ESC>')

  -- More vim mode magic (exit insert mode if you insert jjj or kkk)
  vim.keymap.set('i', 'jjj', '<ESC>jjj')
  vim.keymap.set('i', 'kkk', '<ESC>kkk')

  -- More cleverness... if typing :w<CR> or variations in insert mode, assume you meant to be in normal mode
  vim.keymap.set('i', ':w<CR>', '<CMD>:w<CR>', { noremap = true })
  vim.keymap.set('i', ':wq<CR>', '<CMD>:wq<CR>', { noremap = true })
  vim.keymap.set('i', ':wqa<CR>', '<CMD>:wqa<CR>', { noremap = true })

  -- Save shortcut
  vim.keymap.set({ 'n', 'i' }, '<C-s>', '<CMD>:w<CR>', { noremap = true })

  -- Set register to blackhole
  vim.keymap.set({ 'n', 'v' }, '<leader>B', '"_', { desc = 'Set register to blackhole', silent = true })

  -- Set register to clipboard
  vim.keymap.set({ 'n', 'v', }, '<leader>y', '"+', { desc = 'Set register to clipboard', silent = true })

  -- Mappings for resizing splits.
  vim.keymap.set('n', '<M-C-,>', '<C-w>5<')
  vim.keymap.set('n', '<M-C-.>', '<C-w>5>')
  vim.keymap.set('n', '<M-C-t>', '<C-w>+')
  vim.keymap.set('n', '<M-C-s>', '<C-w>-')

  -- Mappings for resizing splits (insert mode).
  vim.keymap.set('i', '<M-C-,>', '<ESC><C-w>5<a')
  vim.keymap.set('i', '<M-C-.>', '<ESC><C-w>5>a')
  vim.keymap.set('i', '<M-C-t>', '<ESC><C-w>+a')
  vim.keymap.set('i', '<M-C-s>', '<ESC><C-w>-a')

  -- Close the current window/split.
  vim.keymap.set('n', '<leader>X', '<C-w>c', { desc = 'Close the current window/split' })

  -- Close all other buffers.
  vim.keymap.set('n', '<leader>co',
    '<CMD>:let current_pos = getpos(".") | %bd | edit# | bd# | call setpos(".", current_pos)<CR>',
    { desc = 'Close all other buffers' })

  -- Buffer creation.
  vim.keymap.set('n', '<leader>bb', '<CMD>:enew<CR>', { desc = 'New [B]uffer' })
  vim.keymap.set('n', '<leader>bv', '<C-w>v<CMD>:enew<CR>', { desc = 'New [B]uffer [V]ertical Split' })
  vim.keymap.set('n', '<leader>bs', '<C-w>s<CMD>:enew<CR>', { desc = 'New [B]uffer [S]plit' })

  -- Git shortcuts.
  vim.keymap.set('n', 'gbl', '<CMD>:GitBlameToggle<CR>', { desc = '[G]it [B]lame [L]ines' })
  vim.keymap.set('n', 'gbo', '<CMD>:GitBlameOpenFileURL<CR>', { desc = '[G]it [B]lame [O]pen Commit URL' })
end

M.define_luasnip_mappings = function(ls)
  -- -- Expand or jump to the next snippet tabstop
  -- vim.keymap.set({ 'i', 's' }, '<C-k>', function()
  --   if ls.expand_or_jumpable() then
  --     ls.expand_or_jump()
  --   end
  -- end, { silent = true })
  --
  -- -- Jump to the previous snippet tabstop
  -- vim.keymap.set({ 'i', 's' }, '<C-j>', function()
  --   if ls.jumpable(-1) then
  --     ls.jump(-1)
  --   end
  -- end, { silent = true })

  -- Select within a list of options
  vim.keymap.set({ 'i', 's' }, '<C-l>', function()
    if ls.choice_active() then
      ls.change_choice(1)
    end
  end, { silent = true })

  -- Reload snippets for snippet development
  -- vim.keymap.set('n', '<leader>S', function()
  --   ls.cleanup()
  --   vim.cmd 'source ~/.config/nvim/after/plugin/luasnip.lua'
  --   print 'Snippets reloaded'
  -- end, { desc = 'Reload snippets' })
end
return M
