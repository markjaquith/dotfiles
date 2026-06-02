-- PLUGIN: Conform is a plugin that automatically formats your code.

vim.g.format_on_save = vim.g.format_on_save == nil and true or vim.g.format_on_save

local oxfmt_config_files = {
  'oxfmt.config.mts',
  'oxfmt.config.ts',
  'oxfmt.config.mjs',
  'oxfmt.config.js',
  'oxfmt.config.cjs',
  '.oxfmtrc.json',
  '.oxfmtrc.jsonc',
}

local oxfmt_root_markers = {
  '.git',
  'bun.lock',
  'bun.lockb',
  'package-lock.json',
  'package.json',
  'pnpm-lock.yaml',
  'yarn.lock',
}

local function find_oxfmt_config(ctx)
  return vim.fs.find(oxfmt_config_files, {
    path = ctx.dirname,
    upward = true,
    type = 'file',
    limit = 1,
  })[1]
end

local function oxfmt_cwd(_, ctx)
  local config_path = find_oxfmt_config(ctx)
  if config_path then return vim.fs.dirname(config_path) end

  return vim.fs.root(ctx.dirname, oxfmt_root_markers) or ctx.dirname
end

local function oxfmt_args(_, ctx)
  local args = { 'oxfmt' }
  local config_path = find_oxfmt_config(ctx)

  if config_path then
    table.insert(args, '--config=' .. vim.fs.basename(config_path))
  end

  vim.list_extend(args, { '--stdin-filepath', '$FILENAME' })
  return args
end

local function format_ts(bufnr, opts)
  opts = opts or { imports = true }
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  local types = { typescript = true, typescriptreact = true, tsx = true }

  if types[filetype] then
    if opts.imports then
      local max_retries = 5
      local delay = 1000 -- 1 second
      local attempts = 0

      local function try_add_imports()
        -- Check if buffer is still valid before proceeding
        if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
          vim.notify('TypeScript Tools: Buffer no longer valid.', vim.log.levels.WARN)
          return
        end

        local res = pcall(function()
          vim.cmd 'TSToolsAddMissingImports sync'
        end)
        if res then
          pcall(function()
            if vim.fn.exists(':EslintFixAll') == 2 then
              vim.cmd 'EslintFixAll'
            end
          end)
        else
          attempts = attempts + 1
          if attempts < max_retries then
            vim.defer_fn(try_add_imports, delay)
          else
            vim.notify('TypeScript Tools: Failed to add missing imports', vim.log.levels.WARN)
          end
        end
      end

      try_add_imports()
    end

    pcall(function()
      if vim.fn.exists(':EslintFixAll') == 2 then
        vim.cmd 'EslintFixAll'
      end
    end)
  end
end

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>F',
      function()
        format_ts()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = {
    notify_on_error = false,
    run_all_formatters_sequentially = true,
    format_after_save = function(bufnr)
      if not vim.g.format_on_save then return end

      format_ts(bufnr, {
        imports = false,
      })

      -- Disable "format_after_save lsp_fallback" for languages that don't
      -- have a well standardized coding style, or where I want formatting to be manual.
      local disable_filetypes = { c = true, cpp = true, yaml = true }

      -- These types have slow formatters.
      local slow_filetypes = { ruby = true }

      local filetype = vim.bo[bufnr].filetype

      return {
        timeout_ms = slow_filetypes[filetype] and 10000 or 2500,
        lsp_format = 'fallback',
        lsp_fallback = not disable_filetypes[filetype]
      }
    end,
    formatters = {
      bun_oxfmt = {
        command = "bun",
        args = oxfmt_args,
        cwd = oxfmt_cwd,
        stdin = true,
      },

      bunx_oxfmt = {
        command = "bunx",
        args = oxfmt_args,
        cwd = oxfmt_cwd,
        stdin = true,
      },

      -- This one uses --server
      rubocop = {
        command = "bundle",
        args = { "exec", "rubocop", "--autocorrect", "--cache", "true", "--server", "--format", "quiet", "--stderr", "--stdin", "$FILENAME" },
        stdin = true,
      },
      -- This one uses --no-server, in case the server is crashing
      rubocop_cli = {
        command = "bundle",
        args = { "exec", "rubocop", "--autocorrect", "--no-server", "--format", "quiet", "--stderr", "--stdin", "$FILENAME" },
        stdin = true,
      },
    },
    formatters_by_ft = {
      lua = { 'stylua' },
      typescript = { 'bun_oxfmt', 'bunx_oxfmt', stop_after_first = true },
      typescriptreact = { 'bun_oxfmt', 'bunx_oxfmt', stop_after_first = true },
      tsx = { 'bun_oxfmt', 'bunx_oxfmt', stop_after_first = true },
      json = { 'bun_oxfmt', 'bunx_oxfmt', stop_after_first = true },
      ruby = { 'rubocop', 'rubocop_cli' },
      yaml = { 'yamlfix' },
      -- You can use 'stop_after_first' to run the first available formatter from the list
      -- javascript = { "bun_oxfmt", "bunx_oxfmt", stop_after_first = true },
    },
  },
}
