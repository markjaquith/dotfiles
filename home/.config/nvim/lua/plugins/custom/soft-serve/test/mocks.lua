-- test/mocks.lua
-- Mock functions for testing the SoftServe plugin

local M = {}

---@class SoftServeMocks
local mocks = {}

-- Store original functions so we can restore them later
mocks.originals = {}

-- Flag to track if mocks are installed
mocks.installed = false

--- Install mocks for the given module
---@param module table The module to mock functions for
---@param function_name string The name of the function to mock
---@param mock_impl function The mock implementation
function M.mock_function(module, function_name, mock_impl)
  -- Save original function reference if we haven't already
  if not mocks.originals[module] then
    mocks.originals[module] = {}
  end

  if not mocks.originals[module][function_name] then
    mocks.originals[module][function_name] = module[function_name]
  end

  -- Replace with mock implementation
  module[function_name] = mock_impl
end

--- Restore all original functions
function M.restore_all()
  for module, funcs in pairs(mocks.originals) do
    for func_name, orig_func in pairs(funcs) do
      module[func_name] = orig_func
    end
  end
  mocks.originals = {}
end

--- Utility to mock vim.o.columns (editor width)
---@param width integer The mocked width
---@return function A function to restore the original width
function M.mock_editor_width(width)
  local original_columns = vim.o.columns
  vim.o.columns = width

  return function()
    vim.o.columns = original_columns
  end
end

--- Mock the window width functions
---@param win_id integer The window ID
---@param width integer The width to return
function M.mock_window_width(win_id, width)
  local get_width_mock = function(id)
    if id == win_id then
      return width
    end
    -- For other windows, use original function
    return mocks.originals[vim.api]["nvim_win_get_width"](id)
  end

  M.mock_function(vim.api, "nvim_win_get_width", get_width_mock)
end

--- Mock for window creation to simulate split creation
---@param return_win_id integer The window ID to return from the mock
function M.mock_split_creation(return_win_id)
  -- Store original functions
  local original_cmd = vim.api.nvim_command

  -- Mock command execution
  M.mock_function(vim.api, "nvim_command", function(cmd)
    if cmd:match("^vertical") then
      -- It's a split command, return without actual execution
      -- In a real test, you'd have to also mock nvim_get_current_win to return
      -- the expected new window ID after this command runs
      return
    end
    -- Pass through other commands
    return original_cmd(cmd)
  end)

  -- Mock window ID after split
  local original_get_current_win = vim.api.nvim_get_current_win
  M.mock_function(vim.api, "nvim_get_current_win", function()
    -- Check stack trace to determine context - this is a bit of a hack
    local info = debug.getinfo(2, "n")
    if info and info.name and info.name == "create_managed_split" then
      return return_win_id
    end
    -- Default behavior
    return original_get_current_win()
  end)
end

--- Mock time functions to control cooldown behavior
function M.mock_time_functions()
  local mock_time = 0

  -- Mock the get_time_ms function directly in the soft-serve module
  -- Note: This requires modifying the module's local function, which isn't ideal
  -- A better approach would be to refactor the plugin to make this function injectable

  -- Example assuming we can access the function:
  -- M.mock_function(require('soft-serve'), "get_time_ms", function()
  --   return mock_time
  -- end)

  -- Alternative approach: expose a function to advance the mock time
  return function(advance_by)
    mock_time = mock_time + (advance_by or 0)
    return mock_time
  end
end

--- Set up stubs for validation testing
---@param expect_error boolean Whether to expect an error notification
function M.mock_validation(expect_error)
  local notify_called = false

  M.mock_function(vim, "notify", function(msg, level, _)
    if level == vim.log.levels.ERROR and msg:match("Config Error") then
      notify_called = true
    end
  end)

  return function()
    assert.is_true(notify_called == expect_error,
      expect_error and "Expected error notification" or "Did not expect error notification")
  end
end

return M
