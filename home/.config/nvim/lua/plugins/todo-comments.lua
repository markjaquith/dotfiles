-- PLUGIN: Highlight todo, notes, etc in comments
return {
  'folke/todo-comments.nvim',
  event = 'VimEnter',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = {
    -- signs = false,
    keywords = {
      -- FIX: Fix
      -- FIXME: Fixme
      -- BUG: Bug
      -- FIXIT: Fixit
      -- ISSUE: Issue
      -- WRONG: Wrong
      -- ERROR: Error
      FIX = { icon = ' ', color = 'error', alt = { 'FIXME', 'BUG', 'FIXIT', 'ISSUE', 'WRONG', 'ERROR' } },

      -- TODO: Todo
      TODO = { icon = ' ', color = 'info' },

      -- HACK: Hack
      HACK = { icon = ' ', color = 'warning' },

      -- WARN: Warn
      -- WARNING: Warning
      -- XXX: Xxx
      -- DANGER: Danger
      -- BAD: Bad
      WARN = { icon = ' ', color = 'warning', alt = { 'WARNING', 'XXX', 'DANGER', 'BAD' } },

      -- PERF: Perf
      -- OPTIM: Optim
      -- PERFORMANCE: Performance
      -- OPTIMIZE: Optimize
      PERF = { icon = ' ', alt = { 'OPTIM', 'PERFORMANCE', 'OPTIMIZE' } },

      -- NOTE: Note
      -- INFO: Info
      NOTE = { icon = ' ', color = 'hint', alt = { 'INFO' } },

      -- TEST: Test
      -- TESTING: Testing
      -- PASSED: Passed
      -- FAILED: Failed
      TEST = { icon = '⏲ ', color = 'test', alt = { 'TESTING', 'PASSED', 'FAILED' } },

      -- PLUGIN: Plugin
      PLUGIN = { icon = ' ', color = 'plugin' },
    },
    colors = {
      error = { 'DiagnosticError', 'ErrorMsg', '#DC2626' },
      warning = { 'DiagnosticWarn', 'WarningMsg', '#FBBF24' },
      info = { 'DiagnosticInfo', '#2563EB' },
      hint = { 'DiagnosticHint', '#10B981' },
      default = { 'Identifier', '#7C3AED' },
      test = { 'Identifier', '#FF00FF' },
      plugin = { '#a6da95' },
    },
  },
}
