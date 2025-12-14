-- OpenSCAD filetype settings
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.opt_local.expandtab = true

-- Preview the current file in OpenSCAD
vim.keymap.set('n', '<leader>op', function()
  local file = vim.fn.expand '%:p'
  vim.fn.jobstart({ 'openscad', file }, { detach = true })
end, { buffer = true, desc = '[O]penSCAD [P]review' })

-- Render to STL
vim.keymap.set('n', '<leader>or', function()
  local file = vim.fn.expand '%:p'
  local output = vim.fn.expand '%:p:r' .. '.stl'
  vim.fn.jobstart({ 'openscad', '-o', output, file }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify('Rendered to ' .. output, vim.log.levels.INFO)
      else
        vim.notify('Render failed', vim.log.levels.ERROR)
      end
    end,
  })
end, { buffer = true, desc = '[O]penSCAD [R]ender to STL' })
