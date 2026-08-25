-- PLUGIN: Unified Herdr/tmux pane navigation
return {
  {
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
      'TmuxNavigatorProcessList',
    },
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
  },

  {
    'paulbkim-dev/vim-herdr-navigation',
    lazy = false,
    config = function(plugin)
      dofile(plugin.dir .. '/editor/nvim.lua')
    end,
  },
}
