-- test/soft-serve_spec.lua
-- Test suite for soft-serve.lua plugin

-- Import plenary test modules
local assert = require('plenary.assert')
local test = require('plenary.test_harness')
local Window_utils = require('plenary.window')
local Buffer_utils = require('plenary.buffers')

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

-- Ensure the module is loaded
if not try_load_module() then
  error("Failed to load soft-serve module: " .. (load_error or "unknown error"))
end

-- Helper functions for our tests
local helpers = {}

-- Clean up all windows and buffers except for the current one
function helpers.clean_windows()
  -- Get all windows
  local windows = vim.api.nvim_list_wins()
  if #windows > 1 then
    -- Get the current window ID
    local current_win = vim.api.nvim_get_current_win()
    -- Close all other windows
    for _, win_id in ipairs(windows) do
      if win_id ~= current_win then
        pcall(vim.api.nvim_win_close, win_id, true)
      end
    end
  end
end

-- Create a temporary markdown buffer for testing
function helpers.create_test_buffer(filetype)
  filetype = filetype or "markdown"

  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(true, true)

  -- Set its filetype
  vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype)

  -- Load the buffer in the current window
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), bufnr)

  return bufnr
end

-- Set the Neovim window to a specific width
function helpers.set_window_width(width)
  vim.cmd('vertical resize ' .. width)
end

-- Mock the total width of the editor
function helpers.mock_total_width(width)
  local original_columns = vim.o.columns
  vim.o.columns = width
  return function()
    vim.o.columns = original_columns
  end
end

-- Count the number of windows currently open
function helpers.count_windows()
  return #vim.api.nvim_list_wins()
end

-- Get the width of a specific window
function helpers.get_window_width(win_id)
  return vim.api.nvim_win_get_width(win_id)
end

-- Check if a buffer is being managed by SoftServe
function helpers.is_buffer_managed(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return soft_serve.managed_buffers[bufnr] ~= nil
end

-- Wait for a specific condition to be true
function helpers.wait_for(condition, timeout, msg)
  timeout = timeout or 1000 -- default timeout in ms
  msg = msg or "Timed out waiting for condition"

  local start_time
  if vim.loop then
    start_time = vim.loop.now()
  else
    start_time = require('luv').now()
  end

  local elapsed = function()
    if vim.loop then
      return vim.loop.now() - start_time
    else
      return require('luv').now() - start_time
    end
  end

  while elapsed() < timeout do
    if condition() then
      return true
    end
    vim.cmd('sleep 10m') -- Sleep for 10ms
  end

  error(msg)
  return false
end

-- Define the test suite
describe("SoftServe", function()
  -- Run before each test
  before_each(function()
    -- Clean up any existing windows/state
    helpers.clean_windows()
    pcall(soft_serve.cleanup_all) -- Use pcall in case cleanup_all doesn't exist yet

    -- Reset to default config for each test
    soft_serve.setup({
      filetypes = { 'markdown', 'text', 'help', 'man' },
      max_width = 120,
      split_command = 'vertical rightbelow split',
      window_options = {
        wrap = true,
        linebreak = true,
      },
      window_cooldown = 10, -- shorter cooldown for tests
    })
  end)

  -- Run after each test
  after_each(function()
    -- Clean up after test
    pcall(soft_serve.cleanup_all)
    helpers.clean_windows()
  end)

  -- Test basic setup and configuration
  describe("setup", function()
    it("properly initializes with default config", function()
      -- Setup is already called in before_each, but we can check if it's properly initialized
      assert.are.same(soft_serve.config.max_width, 120)
      assert.are.same(type(soft_serve.scratch_bufnr), "number")
      assert.is_true(vim.api.nvim_buf_is_valid(soft_serve.scratch_bufnr))
    end)

    it("can be configured with custom settings", function()
      -- Override with custom config
      soft_serve.setup({
        max_width = 80,
        filetypes = { 'markdown', 'text' }
      })

      assert.are.same(soft_serve.config.max_width, 80)
      assert.are.same(#soft_serve.config.filetypes, 2)
      assert.is_true(soft_serve.filetypes_set['markdown'])
      assert.is_true(soft_serve.filetypes_set['text'])
      assert.is_nil(soft_serve.filetypes_set['help']) -- Should not include help now
    end)

    it("validates configuration options correctly", function()
      -- Setup with invalid config
      soft_serve.setup({
        max_width = "not a number", -- Invalid type
        filetypes = "not a table"   -- Invalid type
      })

      -- Should fall back to defaults
      assert.are.same(soft_serve.config.max_width, 120)
      assert.is_true(type(soft_serve.config.filetypes) == "table")
    end)
  end)

  -- Test core functionality
  describe("window management", function()
    it("creates a split for managed filetypes when width exceeds max_width", function()
      -- Create a markdown buffer (managed filetype)
      local bufnr = helpers.create_test_buffer("markdown")

      -- Mock total width to be larger than max_width
      local restore_width = helpers.mock_total_width(200)

      -- Set window width to be larger than max_width
      helpers.set_window_width(150)

      -- Trigger update
      soft_serve.check_and_update()

      -- Wait for the split to be created
      helpers.wait_for(function()
        return helpers.count_windows() == 2
      end, 500, "Split window was not created")

      -- Verify buffer is managed
      assert.is_true(helpers.is_buffer_managed(bufnr))

      -- Verify the window width is set to max_width
      local current_win = vim.api.nvim_get_current_win()
      assert.are.same(helpers.get_window_width(current_win), 120)

      -- Clean up
      restore_width()
    end)

    it("does not create a split for non-managed filetypes", function()
      -- Create a buffer with non-managed filetype
      local bufnr = helpers.create_test_buffer("lua")

      -- Mock total width to be larger than max_width
      local restore_width = helpers.mock_total_width(200)

      -- Set window width to be larger than max_width
      helpers.set_window_width(150)

      -- Trigger update
      soft_serve.check_and_update()

      -- Verify only one window exists
      assert.are.same(helpers.count_windows(), 1)

      -- Verify buffer is not managed
      assert.is_false(helpers.is_buffer_managed(bufnr))

      -- Clean up
      restore_width()
    end)

    it("removes the split when window width is too small", function()
      -- Create a markdown buffer (managed filetype)
      local bufnr = helpers.create_test_buffer("markdown")

      -- First set up with a large width
      local restore_width = helpers.mock_total_width(200)
      helpers.set_window_width(150)

      -- Trigger update to create the split
      soft_serve.check_and_update()

      -- Wait for the split to be created
      helpers.wait_for(function()
        return helpers.count_windows() == 2
      end, 500, "Split window was not created")

      -- Now change to a small width
      local restore_small_width = helpers.mock_total_width(110)

      -- Wait for cooldown to expire
      vim.cmd('sleep 20m')

      -- Trigger update again
      soft_serve.check_and_update()

      -- Wait for the split to be removed
      helpers.wait_for(function()
        return helpers.count_windows() == 1
      end, 500, "Split window was not removed")

      -- Verify buffer is no longer managed
      assert.is_false(helpers.is_buffer_managed(bufnr))

      -- Clean up
      restore_small_width()
      restore_width()
    end)

    it("applies the correct window options", function()
      -- Create a markdown buffer
      local bufnr = helpers.create_test_buffer("markdown")

      -- Mock total width to be larger than max_width
      local restore_width = helpers.mock_total_width(200)
      helpers.set_window_width(150)

      -- Trigger update
      soft_serve.check_and_update()

      -- Wait for the split to be created
      helpers.wait_for(function()
        return helpers.count_windows() == 2
      end, 500, "Split window was not created")

      -- Get current window (content window)
      local current_win = vim.api.nvim_get_current_win()

      -- Check that window options are set correctly
      assert.is_true(vim.wo[current_win].wrap)
      assert.is_true(vim.wo[current_win].linebreak)

      -- Clean up
      restore_width()
    end)
  end)

  -- Test user commands
  describe("user commands", function()
    it("SoftServeToggle toggles the split state", function()
      -- Create a markdown buffer
      local bufnr = helpers.create_test_buffer("markdown")

      -- Mock total width to be larger than max_width
      local restore_width = helpers.mock_total_width(200)
      helpers.set_window_width(150)

      -- First there should be no split
      assert.are.same(helpers.count_windows(), 1)

      -- Toggle on
      vim.cmd('SoftServeToggle')

      -- Wait for the split to be created
      helpers.wait_for(function()
        return helpers.count_windows() == 2
      end, 500, "Split window was not created by toggle")

      -- Wait for cooldown to expire
      vim.cmd('sleep 20m')

      -- Toggle off
      vim.cmd('SoftServeToggle')

      -- Wait for the split to be removed
      helpers.wait_for(function()
        return helpers.count_windows() == 1
      end, 500, "Split window was not removed by toggle")

      -- Clean up
      restore_width()
    end)

    it("SoftServeDisable removes the split", function()
      -- Create a markdown buffer
      local bufnr = helpers.create_test_buffer("markdown")

      -- Mock total width to be larger than max_width
      local restore_width = helpers.mock_total_width(200)
      helpers.set_window_width(150)

      -- Create split
      vim.cmd('SoftServeEnable')

      -- Wait for the split to be created
      helpers.wait_for(function()
        return helpers.count_windows() == 2
      end, 500, "Split window was not created")

      -- Wait for cooldown to expire
      vim.cmd('sleep 20m')

      -- Now disable
      vim.cmd('SoftServeDisable')

      -- Wait for the split to be removed
      helpers.wait_for(function()
        return helpers.count_windows() == 1
      end, 500, "Split window was not removed by disable")

      -- Verify buffer is no longer managed
      assert.is_false(helpers.is_buffer_managed(bufnr))

      -- Clean up
      restore_width()
    end)
  end)

  -- Test split window behavior
  describe("split window behavior", function()
    it("uses the scratch buffer for the split window", function()
      -- Create a markdown buffer
      local bufnr = helpers.create_test_buffer("markdown")

      -- Mock total width to be larger
