return {
  'markjaquith/back-pocket.nvim',
  lazy = true,
  keys = {
    {
      '<leader>p',
      function()
        require('back-pocket').choose()
      end,
      desc = 'Open Back Pocket command palette',
    },
  },
  config = {
    items = function(ctx)
      local items = {
        {
          name = 'Clear Vim Marks',
          text = 'Delete all marks (local and global)',
          command = function()
            vim.cmd ':delm! | delm A-Z0-9'
            require('snacks').notify('All marks cleared', { title = 'Marks' })
          end,
        },
        {
          name = 'Restart LSP',
          text = 'Restart the langauge server protocol servers',
          command = function()
            vim.cmd 'LspRestart'
            require('snacks').notify('Restarting language servers...', { title = 'LSP' })
          end,
        },
        {
          name = 'Copy Buffer Content',
          text = 'Copy the contents of the current buffer',
          command = function()
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            ctx.copy(table.concat(lines, '\n'), 'Copied buffer contents')
          end,
        },
        {
          name = 'Replace Buffer With Clipboard',
          text = 'Replace the current buffer content with clipboard',
          command = function()
            local clipboard_content = vim.fn.getreg '+'
            local keep_empty_lines = true
            local lines = vim.fn.split(clipboard_content, '\n', keep_empty_lines)
            local error_on_out_of_bounds = false
            local bufnr = 0
            local from = 0
            local to = -1
            vim.api.nvim_buf_set_lines(bufnr, from, to, error_on_out_of_bounds, lines)
            require('snacks').notify('Buffer replaced with clipboard contents', { title = 'Clipboard' })
          end,
        },
      }

      local git_items = {
        {
          name = 'Copy Commit Hash',
          text = 'Copy the hash of the current HEAD',
          command = function()
            local hash = vim.fn.systemlist('git rev-parse HEAD')[1]
            ctx.copy(hash)
          end,
        },
        {
          name = 'Copy Git Branch Name',
          text = ctx.get_git_branch(),
          command = function()
            ctx.copy(ctx.get_git_branch())
          end,
        },
        {
          name = 'Copy GitHub Link',
          text = 'Copy permalink to current file/line on GitHub (HEAD)',
          command = function()
            ctx.copy(ctx.get_github_url())
          end,
        },
        {
          name = 'Open GitHub Link',
          text = 'Open permalink to current file/line on GitHub (HEAD)',
          command = function()
            vim.fn.jobstart({ 'open', ctx.get_github_url() }, { detach = true })
          end,
        },

      }

      local file_items = {
        {
          name = 'Copy File Name',
          text = ctx.file,
          command = function()
            ctx.copy(ctx.file)
          end,
        },
        {
          name = 'Copy File Path (Relative)',
          text = ctx.relative_path,
          command = function()
            ctx.copy(ctx.relative_path)
          end,
        },
        {
          name = 'Copy File Path (Absolute)',
          text = ctx.absolute_path,
          command = function()
            ctx.copy(ctx.absolute_path)
          end,
        },
      }

      if string.len(ctx.file) > 0 then
        items = vim.list_extend(items, file_items)
      end

      if ctx.in_git_repo() then
        items = vim.list_extend(items, git_items)
      end

      return items
    end,
  }
}
