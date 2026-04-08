-- PLUGIN: Treesitter is a plugin that highlights, edits, and navigates code.
return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  build = function()
    require('nvim-treesitter').update({ 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }):wait(300000)
  end,
  opts = {},
  init = function()
    vim.api.nvim_create_autocmd('FileType', {
      callback = function(args)
        local filetype = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(filetype) or filetype

        if lang == '' then
          return
        end

        pcall(vim.treesitter.start, args.buf, lang)

        if lang ~= 'markdown' and lang ~= 'markdown_inline' then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end

        local win = vim.api.nvim_get_current_win()
        vim.wo[win].foldmethod = 'expr'
        vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      end,
    })
  end,
  config = function(_, opts)
    local languages = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
    local treesitter = require('nvim-treesitter')

    treesitter.setup(opts)

    local installed = treesitter.get_installed()
    local missing = vim.tbl_filter(function(lang)
      return not vim.tbl_contains(installed, lang)
    end, languages)

    if #missing > 0 then
      treesitter.install(missing):wait(300000)
    end

    local version = vim.version()
    local nvim_version = string.format('%d.%d.%d', version.major, version.minor, version.patch)
    local marker = vim.fn.stdpath('state') .. '/nvim-treesitter-version'
    local previous = vim.fn.filereadable(marker) == 1 and vim.fn.readfile(marker)[1] or nil

    -- Rebuild parser binaries once after a Neovim upgrade to avoid ABI mismatches.
    if previous ~= nvim_version then
      treesitter.update(languages):wait(300000)
      vim.fn.mkdir(vim.fn.fnamemodify(marker, ':h'), 'p')
      vim.fn.writefile({ nvim_version }, marker)
    end

    vim.opt.foldtext = ''
  end,
}
