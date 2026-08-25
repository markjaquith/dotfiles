-- Set space as the leader key.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Disable netrw. Other plugins will handle file browsing.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Announce we have nerd font available for icons.
vim.g.have_nerd_font = true

-- Relative line numbers.
vim.opt.number = true
vim.opt.relativenumber = false

-- Configure line folding
vim.opt.foldlevel = 99
vim.opt.foldnestmax = 4
vim.opt.foldminlines = 3
vim.opt.foldenable = true

-- Enable the mouse.
vim.opt.mouse = 'a' -- Enable mouse support for all modes

-- Disable left-click in Normal and Visual modes
-- Not sure why I did this, but it prevented splits from being resized.
-- vim.api.nvim_create_autocmd({ 'VimEnter' }, {
--   pattern = '*',
--   callback = function()
--     vim.cmd [[noremap <LeftMouse> <Nop>]]
--     vim.cmd [[noremap! <LeftMouse> <Nop>]]
--   end,
-- })

-- Always show tabline
-- vim.opt.showtabline = 2

-- Don't show the mode, since it's already in the status line.
vim.opt.showmode = true

-- Enable break indent.
vim.opt.breakindent = true

-- Save undo history.
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term.
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default. This is where things like Git and debug markers show.
vim.opt.signcolumn = 'yes'

-- Decrease update time.
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time.
-- Displays which-key popup sooner.
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened.
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--  Tab needs to be two or three characters.
vim.opt.list = true
vim.opt.listchars = {
  tab = '   ', -- '» ',
  trail = '·',
  nbsp = '␣',
}

-- Configure tabs and such.
vim.o.expandtab = false
vim.o.softtabstop = 2

-- Preview substitutions live.
vim.opt.inccommand = 'split'

-- Show which line your cursor is on.
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 12
