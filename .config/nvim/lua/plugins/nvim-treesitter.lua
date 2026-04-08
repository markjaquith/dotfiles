-- PLUGIN: Treesitter is a plugin that highlights, edits, and navigates code.
return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  opts = {
    ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' },
    -- Autoinstall languages that are not installed
    auto_install = true,
    highlight = {
      enable = true,
      -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
      --  If you are experiencing weird indenting issues, add the language to
      --  the list of additional_vim_regex_highlighting and disabled languages for indent.
      additional_vim_regex_highlighting = { 'ruby' },
    },
    indent = { enable = true, disable = { 'ruby' } },
    fold = { enable = true },
  },
  config = function(_, opts)
    require('nvim-treesitter.configs').setup(opts)

    local version = vim.version()
    local nvim_version = string.format('%d.%d.%d', version.major, version.minor, version.patch)
    local marker = vim.fn.stdpath('state') .. '/nvim-treesitter-version'
    local previous = vim.fn.filereadable(marker) == 1 and vim.fn.readfile(marker)[1] or nil

    -- Rebuild parser binaries once after a Neovim upgrade to avoid ABI mismatches.
    if previous ~= nvim_version then
      vim.cmd 'TSUpdateSync'
      vim.fn.mkdir(vim.fn.fnamemodify(marker, ':h'), 'p')
      vim.fn.writefile({ nvim_version }, marker)
    end

    -- Use treesitter for folding
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.opt.foldtext = ''
  end,
}
