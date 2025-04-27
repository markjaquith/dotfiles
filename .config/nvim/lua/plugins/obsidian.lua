return {
  'obsidian-nvim/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = 'markdown',
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre path/to/my-vault/*.md",
  --   "BufNewFile path/to/my-vault/*.md",
  -- },
  dependencies = {
    -- Required.
    'nvim-lua/plenary.nvim',

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = 'main',
        path = '~/Documents/Obsidian',
      },
    },

    -- see below for full list of options 👇
    daily_notes = {
      -- Optional, if you keep daily notes in a separate directory.
      folder = 'Daily Notes',
      -- Optional, if you want to change the date format for the ID of daily notes.
      date_format = '%Y/%m-%B/%Y-%m-%d',
      -- Optional, if you want to change the date format of the default alias of daily notes.
      -- alias_format = '%B %-d, %Y',
      -- Optional, default tags to add to each new daily note created.
      -- default_tags = { 'daily-notes' },
      -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
      template = 'Templates/Daily Note Template',
    },

    -- Optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
    completion = {
      -- Enables completion using nvim_cmp
      nvim_cmp = true,
      -- Enables completion using blink.cmp
      blink = false,
      -- Trigger completion at 2 chars.
      min_chars = 2,
    },
  },
}
