-- PLUGIN: Collection of useful tools

vim.api.nvim_create_autocmd('User', {
  pattern = 'OilActionsPost',
  callback = function(event)
    if event.data.actions.type == 'move' then
      Snacks.rename.on_rename_file(event.data.actions.src_url, event.data.actions.dest_url)
    end
  end,
})

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true },
    explorer = { enabled = true, replace_netrw = false },
    notifier = { enabled = true },
    dim = { enabled = true },
    scroll = { enabled = true },
    indent = {
      enabled = true,
      animate = {
        -- enabled = false
        duration = {
          step = 15,   -- ms per step
          total = 200, -- maximum duration
        },
      },
    },
    rename = { enabled = true },
    scratch = { enabled = true },
    toggle = { enabled = true },
    picker = {
      enabled = true,
      layout = 'ivy_split',
      formatters = {
        file = {
          truncate = vim.api.nvim_win_get_width(0) - 10,
        },
      },
      sources = {
        explorer = {
          hidden = true,
        },
      },
      config = function(opts)
        opts.formatters.file.truncate = vim.api.nvim_win_get_width(0) - 10
      end,
      matcher = {
        cwd_bonus = true,
        frecency = true,
        history_bonus = true,
      },
      -- win = {
      --   input = {
      --     keys = {
      --       ['<c-q>'] = {
      --         function(picker)
      --           picker.qflist()
      --           vim.cmd('cclose')
      --         end,
      --         mode = { "i", "n" }
      --       }
      --     }
      --   }
      -- }
    },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    lazygit = { enabled = true },
  },
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>ow'
        Snacks.toggle.option('relativenumber', { name = 'Relative Line Numbers' }):map '<leader>or'
        Snacks.toggle.line_number():map '<leader>ol'
        Snacks.toggle.dim():map '<leader>od'
      end,
    })
  end,
  keys = function()
    local base_keys = {
      -- NOTE: Buffer
      {
        '<leader>x',
        function()
          Snacks.bufdelete()
        end,
        desc = 'Delete the current buffer',
      },

      -- NOTE: Picker
      -- Explorer
      {
        '<leader>T',
        function()
          Snacks.explorer.reveal()
        end,
        { desc = 'Toggle File [T]ree' },
      },

      -- NOTE: Find
      {
        '<leader>fb',
        function()
          Snacks.picker.buffers()
        end,
        desc = '[F]ind [B]uffers',
      },
      {
        '<leader>ff',
        function()
          Snacks.picker.files()
        end,
        desc = '[F]ind [F]iles',
      },
      {
        '<leader>fg',
        function()
          Snacks.picker.git_files()
        end,
        desc = '[F]ind [G]it Files',
      },
      {
        '<leader>fr',
        function()
          Snacks.picker.recent()
        end,
        desc = '[F]ind [R]ecent Files',
      },
      {
        '<leader><leader>',
        function()
          Snacks.picker.buffers()
        end,
        desc = '[ ] Find Buffers',
      },

      -- NOTE: Search
      {
        '<leader>sh',
        function()
          Snacks.picker.help()
        end,
        desc = '[S]earch [H]elp',
      },
      {
        '<leader>sk',
        function()
          Snacks.picker.keymaps()
        end,
        desc = '[S]earch [K]eymaps',
      },
      {
        '<leader>sc',
        function()
          Snacks.picker.commands()
        end,
        desc = '[S]earch [C]ommands',
      },
      {
        '<leader>ss',
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = '[S]earch [S]ymbol',
      },
      {
        '<leader>sS',
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = '[S]earch Workspace [S]ymbols',
      },
      {
        '<leader>sw',
        function()
          Snacks.picker.grep_word()
        end,
        desc = '[S]earch Current [W]ord',
      },
      {
        '<leader>sg',
        function()
          Snacks.picker.grep()
        end,
        desc = '[S]earch [G]rep',
      },
      {
        '<leader>sd',
        function()
          Snacks.picker.diagnostics()
        end,
        desc = '[S]earch [D]iagnostics',
      },
      {
        '<leader>sr',
        function()
          Snacks.picker.resume()
        end,
        desc = '[S]earch [R]esume',
      },
      {
        '<leader>s/',
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = '[S]earch in Buffers',
      },
      {
        '<leader>sm',
        function()
          Snacks.picker.marks()
        end,
        desc = '[S]earch [M]arks',
      },
      {
        '<leader>s"',
        function()
          Snacks.picker.registers()
        end,
        desc = '[S]earch [R]egisters',
      },
      {
        '<leader>sb',
        function()
          Snacks.picker.buffers()
        end,
        desc = '[S]earch [B]uffer',
      },
      {
        '<leader>sp',
        function()
          Snacks.picker.lazy()
        end,
        desc = '[S]earch [P]lugins',
      },
      {
        '<leader>su',
        function()
          Snacks.picker.undo()
        end,
        desc = '[S]earch [U]ndo',
      },

      -- NOTE: LSP
      {
        'gd',
        function()
          Snacks.picker.lsp_definitions()
        end,
        desc = '[G]oto [D]efinition',
      },
      {
        'gr',
        function()
          Snacks.picker.lsp_references()
        end,
        desc = '[G]oto [R]eferences',
      },
      {
        'gI',
        function()
          Snacks.picker.lsp_implementations()
        end,
        desc = '[G]oto [I]mplementation',
      },
      {
        '<leader>D',
        function()
          Snacks.picker.lsp_type_definitions()
        end,
        desc = 'Type [D]efinition',
      },
      {
        '<leader>ds',
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = '[D]ocument [S]ymbols',
      },
      {
        '<leader>Ws',
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = '[W]orkspace [S]ymbols',
      },

      -- NOTE: Notifier
      {
        '<leader>nn',
        function()
          Snacks.notifier.show_history()
        end,
        desc = '[N]otifications',
      },
      {
        '<leader>nh',
        function()
          Snacks.notifier.hide()
        end,
        desc = '[N]otifications [H]ide',
      },

      -- NOTE: Words
      {
        ']]',
        function()
          Snacks.words.jump(vim.v.count1)
        end,
        desc = 'Next Reference',
        mode = { 'n', 't' },
      },
      {
        '[[',
        function()
          Snacks.words.jump(-vim.v.count1)
        end,
        desc = 'Prev Reference',
        mode = { 'n', 't' },
      },
    }

    local local_keys_path = vim.fn.expand('~/.local-dotfiles/.config/nvim/lua/local/keys/snacks.lua')
    local local_keys = {}

    if vim.fn.filereadable(local_keys_path) == 1 then
      local status_ok, result = pcall(dofile, local_keys_path)

      if status_ok then
        if type(result) == 'table' then
          local_keys = result
        else
          vim.notify("Local Snacks keys file did not return a table: " .. local_keys_path, vim.log.levels.WARN)
        end
      else
        vim.notify("Error executing local Snacks keys file: " .. local_keys_path .. "\n" .. tostring(result),
          vim.log.levels.ERROR)
      end
    end

    local merged_keys = vim.list_extend(base_keys, local_keys)

    return merged_keys
  end
}
