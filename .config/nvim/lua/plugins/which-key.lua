-- PLUGIN: WhichKey shows pending keybinds as you press them.
return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  opts = {
    -- NOTE: Delay in ms
    delay = 1000,
    spec = {
      { '<leader>c', group = '[C]ode' },
      { '<leader>d', group = '[D]ocument' },
      { '<leader>b', group = '[B]uffer' },
      { '<leader>r', group = '[R]ename' },
      { '<leader>f', group = '[F]ind' },
      { '<leader>w', group = '[W]indow' },
      { '<leader>W', group = '[W]orkspace' },
      { '<leader>n', group = '[N]otifications' },
      { '<leader>g', group = '[G]it' },
      { '<leader>s', group = '[S]earch' },
      { '<leader>S', group = '[S]ession' },
      { '<leader>l', group = '[L]SP' },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>h', group = 'Git [H]unk',     mode = { 'n', 'v' } },
      { '<leader>w', proxy = '<c-w>',          group = 'windows' },
    },
  },
  keys = {
    {
      '<leader>?',
      function()
        require('which-key').show { global = false }
      end,
    },
  },
}
