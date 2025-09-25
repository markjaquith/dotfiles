-- PLUGIN: Launch tests from their file
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-jest",
    "olimorris/neotest-rspec",
    "thenbe/neotest-playwright",
  },
  opts = function()
    return {
      discovery = {
        enabled = false,
        concurrent = 1,
      },
      running = {
        concurrent = true,
      },
      summary = {
        animated = false,
      },
      adapters = {
        require("neotest-jest")({
          jestCommand = "yarn test",
        }),
        require("neotest-rspec") {
          root_files = { 'Gemfile' },
          engine_support = false,
        },
        -- require("neotest-playwright"),
      }
    }
  end,
  keys = {
    {
      "<leader>Tf",
      function()
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "[T]est current [f]ile"
    },
    {
      "<leader>Tn",
      function()
        require("neotest").run.run()
      end,
      desc = "[T]est [n]earest"
    },
  },
}