-- PLUGIN: Much better TypeScript integration
return {
  'pmizio/typescript-tools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
  opts = {
    settings = {
      tsserver_max_memory = 8192,
    }
  },
}
