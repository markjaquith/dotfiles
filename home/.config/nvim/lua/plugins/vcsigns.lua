-- PLUGIN: Shows VCS changes in the gutter, including jj changes against @-.
return {
  'algmyr/vcsigns.nvim',
  dependencies = {
    'algmyr/vclib.nvim',
    'lewis6991/async.nvim',
  },
  opts = {
    target_commit = 1,
    show_delete_count = false,
    signs = {
      text = {
        add = '┃',
        change = '┃',
        delete_below = '_',
        delete_above = '‾',
        combined = '~',
      },
    },
  },
  config = function(_, opts)
    require('vcsigns').setup(opts)
    local actions = require 'vcsigns.actions'

    vim.keymap.set('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal { ']c', bang = true }
      else
        actions.hunk_next(0, vim.v.count1)
      end
    end, { desc = 'Jump to next VCS [c]hange' })

    vim.keymap.set('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal { '[c', bang = true }
      else
        actions.hunk_prev(0, vim.v.count1)
      end
    end, { desc = 'Jump to previous VCS [c]hange' })

    vim.keymap.set({ 'n', 'v' }, '<leader>hr', function()
      actions.hunk_undo(0)
    end, { desc = 'VCS [r]estore hunk' })
    vim.keymap.set('n', '<leader>hp', function()
      actions.toggle_hunk_diff(0)
    end, { desc = 'VCS [p]review hunk' })
    vim.keymap.set('n', '<leader>hd', function()
      actions.diffview(0)
    end, { desc = 'VCS [d]iff against parent' })
  end,
}
