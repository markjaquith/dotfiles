-- Rex side of Ctrl-H/J/K/L navigation, matching vim-herdr-navigation: move
-- between Neovim splits, and at a split edge move Rex's pane focus. Herdr's
-- own mappings apply inside Herdr, including a Herdr running inside Rex.
local M = {}

function M.setup()
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= '' then
    return
  end
  if not vim.env.REX_SESSION or vim.env.REX_SESSION == '' then
    return
  end

  local function nav(wincmd, dir)
    local prev = vim.api.nvim_get_current_win()
    vim.cmd('wincmd ' .. wincmd)
    if vim.api.nvim_get_current_win() ~= prev then
      return
    end
    vim.fn.system({
      'rex', '--autostart=false', 'api', 'call', '-s', vim.env.REX_SESSION,
      'session.focus_direction', vim.json.encode({ direction = dir }),
    })
  end

  for lhs, spec in pairs({
    ['<C-h>'] = { 'h', 'left' },
    ['<C-j>'] = { 'j', 'down' },
    ['<C-k>'] = { 'k', 'up' },
    ['<C-l>'] = { 'l', 'right' },
  }) do
    vim.keymap.set('n', lhs, function()
      nav(spec[1], spec[2])
    end, { silent = true, noremap = true, desc = 'Navigate ' .. spec[2] .. ' (vim/rex)' })
  end
end

return M
