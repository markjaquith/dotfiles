-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

local macro_group = vim.api.nvim_create_augroup('MacroRecording', { clear = true })
vim.api.nvim_create_autocmd('RecordingEnter', {
  group = macro_group,
  callback = function()
    print('Recording @' .. vim.fn.reg_recording())
  end,
})
vim.api.nvim_create_autocmd('RecordingLeave', {
  group = macro_group,
  callback = function()
    print('Recorded @' .. vim.v.event.regname)
  end,
})

-- Recognize files with shebangs
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*',
  callback = function()
    local first_line = vim.fn.getline(1)
    local shebang_ft = {
      bash = 'sh',
      sh = 'sh',
      zsh = 'sh',
      python = 'python',
      perl = 'perl',
      ruby = 'ruby',
      node = 'javascript',
      bun = 'typescript',
    }

    for interpreter, ft in pairs(shebang_ft) do
      if first_line:match('^#!.*' .. interpreter) then
        vim.bo.filetype = ft
        break
      end
    end
  end,
})
