-- PLUGIN: GitHub Copilot (Lua rewrite)
-- https://github.com/zbirenbaum/copilot.lua

return {
  'zbirenbaum/copilot.lua',
  cmd = 'Copilot',
  event = 'InsertEnter',
  opts = {
    suggestion = {
      enabled = true,
      auto_trigger = true,
      keymap = {
        accept = '<Tab>',
        dismiss = '<C-]>',
        next = '<M-]>',
        prev = '<M-[>',
      },
    },
    panel = {
      enabled = false,
    },
  },
}
