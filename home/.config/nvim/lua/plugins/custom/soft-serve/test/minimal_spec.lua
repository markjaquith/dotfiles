-- test/minimal_spec.lua
-- A minimal test file to get started with SoftServe testing

-- Import plenary test modules
local assert = require('plenary.assert')

-- Try to load the module with error handling
local soft_serve, load_error
local function try_load_module()
  -- Try standard require first
  local ok, result = pcall(require, 'soft-serve')
  if ok then
    soft_serve = result
    return true
  end

  -- If that failed, try with explicit path
  ok, result = pcall(require, 'lua.soft-serve.init')
  if ok then
    soft_serve = result
    print("Loaded module with explicit path")
    return true
  end

  -- Both attempts failed
  load_error = result
  return false
end

-- Basic helper function
local function create_test_buffer(filetype)
  filetype = filetype or "markdown"
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype)
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), bufnr)
  return bufnr
end

-- Test suite
describe("SoftServe Module Loading", function()
  it("loads the module successfully", function()
    local loaded = try_load_module()
    assert.is_true(loaded, "Failed to load soft-serve module: " .. (load_error or "unknown error"))
    assert.is_not_nil(soft_serve)
    assert.is_table(soft_serve)
    assert.is_function(soft_serve.setup)
  end)
end)

-- Only run the rest of tests if the module loaded successfully
if soft_serve then
  describe("SoftServe Minimal Tests", function()
    -- Run before each test
    before_each(function()
      -- Reset to default config
      soft_serve.setup({
        filetypes = { 'markdown', 'text' },
        max_width = 100,
      })
    end)

    -- Run after each test
    after_each(function()
      -- Clean up
      soft_serve.cleanup_all()
    end)

    -- Basic test
    it("correctly identifies managed filetypes", function()
      -- Test with managed filetype
      local md_bufnr = create_test_buffer("markdown")
      local current_ft = vim.bo[md_bufnr].filetype
      assert.are.same(current_ft, "markdown")
      assert.is_true(soft_serve.filetypes_set[current_ft])

      -- Test with unmanaged filetype
      local lua_bufnr = create_test_buffer("lua")
      local lua_ft = vim.bo[lua_bufnr].filetype
      assert.are.same(lua_ft, "lua")
      assert.is_nil(soft_serve.filetypes_set[lua_ft])
    end)

    -- Test configuration
    it("applies custom configuration correctly", function()
      -- Test default settings from before_each
      assert.are.same(soft_serve.config.max_width, 100)
      assert.are.same(#soft_serve.config.filetypes, 2)

      -- Change configuration
      soft_serve.setup({
        max_width = 80,
        filetypes = { 'markdown', 'text', 'help' },
      })

      -- Test new settings
      assert.are.same(soft_serve.config.max_width, 80)
      assert.are.same(#soft_serve.config.filetypes, 3)
      assert.is_true(soft_serve.filetypes_set['help'])
    end)
  end)
end
