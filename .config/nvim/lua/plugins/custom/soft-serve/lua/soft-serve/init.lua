-- soft-serve.lua
-- A Neovim plugin to manage window width for files with long lines

---@class SoftServe
local M = {}

---@class SoftServeConfig
---@field filetypes string[] List of filetypes to manage. Defaults to {'markdown', 'text', 'help', 'man'}.
---@field max_width integer Maximum width for the content window. Defaults to 120.
---@field split_command string Vim command used to create the side split window. Defaults to 'vertical rightbelow split'.
---@field window_options table<string, any> Window-local options for the main content window when managed. Defaults to { wrap = true, linebreak = true }.
---@field window_cooldown integer Cooldown period in milliseconds after window operations to prevent rapid changes. Defaults to 300.

--- Default configuration
---@type SoftServeConfig
M.config = {
  filetypes = { 'markdown', 'text', 'help', 'man' },
  max_width = 120,
  split_command = 'vertical rightbelow split',
  window_options = {
    wrap = true,
    linebreak = true,
    -- Consider adding list = false, listchars = 'eol: ' if you don't want list chars with wrap
  },
  window_cooldown = 300,
}

---@class ManagedBufferInfo
---@field content_win integer The window ID of the main content window.
---@field split_win integer The window ID of the adjacent split window (displaying the scratch buffer).

-- State tracking
--- Tracks managed buffers: { bufnr -> ManagedBufferInfo }
---@type table<integer, ManagedBufferInfo>
M.managed_buffers = {}

--- Buffer number for the single shared scratch buffer used in splits.
---@type integer? # nil until setup initializes it
M.scratch_bufnr = nil

--- Set derived from config.filetypes for faster lookups: { filetype -> true }
---@type table<string, boolean>
M.filetypes_set = {}

--- Timestamp (vim.loop.now()) of the last window modification action (split creation/removal/resize).
---@type integer
M.last_window_operation = 0

-- --- Helper Functions ---

--- Get current time in milliseconds using Neovim's loop timer.
---@return integer Current time in milliseconds.
local function get_time_ms()
  return require('luv').now()
end

--- Check if we are within the cooldown period after a window operation.
---@return boolean True if within cooldown, false otherwise.
local function is_in_cooldown()
  return (get_time_ms() - M.last_window_operation) < M.config.window_cooldown
end

--- Register that a window operation has occurred, starting the cooldown.
local function register_window_operation()
  M.last_window_operation = get_time_ms()
end

--- Check if the current buffer's filetype is configured to be managed.
---@return boolean True if the filetype should be managed, false otherwise.
local function should_manage_buffer()
  local current_ft = vim.bo.filetype
  return M.filetypes_set[current_ft] == true
end

--- Get the total width of the Neovim editor (all columns).
---@return integer The value of vim.o.columns.
local function get_total_width()
  return vim.o.columns
end

-- --- Core Logic Functions ---

--- Remove the managed state and close the associated split window for a given buffer.
--- Registers a window operation cooldown. Handles window/buffer validity checks.
---@param bufnr integer The buffer number to stop managing.
---@return boolean True if the buffer was managed and cleanup was attempted, false otherwise.
local function remove_managed_split(bufnr)
  local info = M.managed_buffers[bufnr]
  if info then
    register_window_operation() -- Register before potential triggers

    -- Close the split window ONLY if it's valid and contains our scratch buffer
    if vim.api.nvim_win_is_valid(info.split_win) then
      local win_buf = vim.api.nvim_win_get_buf(info.split_win)
      -- Check buffer validity too, just in case
      if vim.api.nvim_buf_is_valid(win_buf) and win_buf == M.scratch_bufnr then
        -- Use pcall as closing can sometimes error, though force=true helps
        pcall(vim.api.nvim_win_close, info.split_win, true) -- Force close
      end
    end

    -- Restore default window options on the content window? (Optional, depends on desired behavior)
    -- Example: vim.wo[info.content_win].wrap = vim.opt.wrap:get() -- Reset to global default
    -- For now, we assume the user wants the options to persist until they change buffer/filetype

    -- Clean up tracking state for this buffer
    M.managed_buffers[bufnr] = nil
    vim.cmd 'redraw' -- Redraw to reflect changes immediately
    return true
  end
  return false
end

--- Create a split window to manage width for the current buffer.
--- Applies configured options to the content window and sets up the scratch split.
--- Registers a window operation cooldown. Checks cooldown before proceeding.
---@return boolean True if the split was successfully created, false otherwise (e.g., cooldown active, already managed, error).
local function create_managed_split()
  -- Safety check: Abort if in cooldown
  if is_in_cooldown() then
    return false
  end

  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_winnr = vim.api.nvim_get_current_win()

  -- Check if buffer is already managed (e.g., rapid events)
  if M.managed_buffers[current_bufnr] then
    return false
  end

  -- Ensure our scratch buffer is valid
  if not M.scratch_bufnr or not vim.api.nvim_buf_is_valid(M.scratch_bufnr) then
    vim.notify('SoftServe: Scratch buffer is invalid!', vim.log.levels.ERROR)
    return false
  end

  register_window_operation() -- Register action before creating split

  -- Create the split using the configured command
  local ok, err = pcall(vim.api.nvim_command, M.config.split_command)
  if not ok then
    vim.notify('SoftServe: Unable to create split: ' .. tostring(err), vim.log.levels.ERROR)
    M.last_window_operation = 0 -- Reset cooldown as operation failed early
    return false
  end

  -- New window is now the current window
  local split_win = vim.api.nvim_get_current_win()

  -- Set the new split window to use our shared empty scratch buffer
  pcall(vim.api.nvim_win_set_buf, split_win, M.scratch_bufnr)

  -- Configure the appearance of the split window (make it passive)
  local split_wo = vim.wo[split_win]
  split_wo.number = false
  split_wo.relativenumber = false
  split_wo.cursorline = false
  split_wo.signcolumn = 'no'
  split_wo.foldcolumn = '0'
  split_wo.colorcolumn = ''
  split_wo.winhighlight = 'Normal:NormalNC,EndOfBuffer:NormalNC' -- Make it look inactive
  split_wo.fillchars = 'eob: '                                   -- Hide '~' at end of buffer

  -- Go back to the original window (content window)
  vim.api.nvim_set_current_win(current_winnr)

  -- Resize the original (content) window to our max width
  pcall(vim.api.nvim_win_set_width, current_winnr, M.config.max_width)

  -- Apply configured window options to the content window
  local content_wo = vim.wo[current_winnr]
  for option, value in pairs(M.config.window_options) do
    content_wo[option] = value
  end

  -- Store information about this managed buffer
  M.managed_buffers[current_bufnr] = {
    content_win = current_winnr,
    split_win = split_win,
  }

  vim.cmd 'redraw' -- Redraw to reflect changes
  return true
end

--- Check the current buffer/window state and create/remove/adjust splits as needed.
--- This is the core logic function called by autocommands.
--- Checks cooldown and vim.in_fast_event before proceeding.
function M.check_and_update()
  -- Abort immediately if triggered during a cooldown period
  if is_in_cooldown() then
    return
  end

  -- Skip if Neovim is busy with fast events (e.g., rapid window changes)
  -- Schedule a check for later if needed.
  if vim.in_fast_event and vim.in_fast_event() then
    -- Use schedule instead of direct call to avoid potential recursion or race conditions
    vim.schedule(M.check_and_update)
    return
  end

  -- Only proceed if the current buffer's filetype is managed
  if not should_manage_buffer() then
    local current_winnr = vim.api.nvim_get_current_win()
    -- Check if any managed buffer is associated with the current window
    for bufnr, info in pairs(M.managed_buffers) do
      if info.content_win == current_winnr then
        remove_managed_split(bufnr)
        break
      end
    end
    return
  end

  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_winnr = vim.api.nvim_get_current_win()
  local total_width = get_total_width()
  local is_managed = M.managed_buffers[current_bufnr] ~= nil

  if is_managed then
    local info = M.managed_buffers[current_bufnr]
    -- Ensure our tracked windows are still valid
    if not vim.api.nvim_win_is_valid(info.content_win) or not vim.api.nvim_win_is_valid(info.split_win) then
      -- A window disappeared unexpectedly, cleanup state. remove_managed_split handles cooldown.
      remove_managed_split(current_bufnr)
      return
    end

    -- If the total editor width is too small, remove the split
    -- Use a small buffer (e.g., 2 cols) to avoid flicker when resizing near threshold
    if total_width <= M.config.max_width + 2 then
      remove_managed_split(current_bufnr)
    else
      -- Ensure the content window width is maintained if total width is sufficient
      -- Only resize if it's not already the target width (avoid unnecessary operations/cooldown)
      if vim.api.nvim_win_get_width(info.content_win) ~= M.config.max_width then
        register_window_operation() -- Register before resizing
        pcall(vim.api.nvim_win_set_width, info.content_win, M.config.max_width)
      end
      -- Ensure window options are still applied (might be overwritten by user/other plugins)
      -- Consider efficiency: maybe only check/apply if needed, or only on creation?
      -- Current approach is safer but might do slightly more work.
      local content_wo = vim.wo[info.content_win]
      for option, value in pairs(M.config.window_options) do
        if content_wo[option] ~= value then
          content_wo[option] = value
        end
      end
    end
  else
    -- Not managed currently. Check if we should create a split.
    -- Only create if total width exceeds max_width AND current window itself is wider than max_width
    if total_width > M.config.max_width then
      local current_win_width = vim.api.nvim_win_get_width(current_winnr)
      -- Check if the current window is the only window (or main large window)
      -- We check current_win_width > max_width to avoid creating splits if the target
      -- window is already narrow due to other splits.
      if current_win_width > M.config.max_width then
        -- create_managed_split handles cooldown registration
        create_managed_split()
      end
    end
  end
end

--- Clean up all managed buffers and their associated split windows.
function M.cleanup_all()
  -- Create a copy of keys to avoid issues while iterating and modifying the table
  local buffers_to_cleanup = {}
  for bufnr, _ in pairs(M.managed_buffers) do
    table.insert(buffers_to_cleanup, bufnr)
  end
  for _, bufnr in ipairs(buffers_to_cleanup) do
    -- remove_managed_split handles validity checks and cooldown registration internally
    remove_managed_split(bufnr)
  end
end

--- Get the status string for display (e.g., in statusline).
--- Returns an icon or text if the current buffer is managed, empty string otherwise.
---@return string Status indicator string.
function M.status()
  local bufnr = vim.api.nvim_get_current_buf()
  if M.managed_buffers[bufnr] then
    return '󰙴 ' -- Nerd Font icon for wrap (adjust as desired)
    -- return 'SW' -- Simpler text alternative
  else
    return ''
  end
end

-- --- Configuration and Setup ---

--- Validate user-provided configuration options.
--- Notifies user of errors for invalid types.
---@param user_config table The user's configuration table.
---@return boolean True if configuration is valid, false otherwise.
local function validate_config(user_config)
  local valid = true
  local log_error = function(msg)
    vim.notify('SoftServe Config Error: ' .. msg, vim.log.levels.ERROR)
    valid = false
  end

  -- Validate types, allowing nil (which means use default)
  if user_config.max_width ~= nil and type(user_config.max_width) ~= 'number' then
    log_error 'max_width must be a number.'
    user_config.max_width = nil -- Prevent merging invalid type by setting it back to nil
  end

  if user_config.filetypes ~= nil and type(user_config.filetypes) ~= 'table' then
    log_error 'filetypes must be a table (list of strings).'
    user_config.filetypes = nil
  elseif user_config.filetypes then -- Check contents if it is a table
    for i, ft in ipairs(user_config.filetypes) do
      if type(ft) ~= 'string' then
        log_error(string.format('filetypes entry #%d ("%s") must be a string.', i, tostring(ft)))
        -- Decide: remove entry or invalidate whole config? Invalidate is safer.
        valid = false
        break -- Stop checking filetypes
      end
    end
    if not valid then
      user_config.filetypes = nil
    end -- Don't merge invalid filetypes table
  end

  if user_config.window_options ~= nil and type(user_config.window_options) ~= 'table' then
    log_error 'window_options must be a table.'
    user_config.window_options = nil
  end

  if user_config.split_command ~= nil and type(user_config.split_command) ~= 'string' then
    log_error 'split_command must be a string.'
    user_config.split_command = nil
  end

  if user_config.window_cooldown ~= nil and type(user_config.window_cooldown) ~= 'number' then
    log_error 'window_cooldown must be a number (milliseconds).'
    user_config.window_cooldown = nil
  end

  return valid
end

--- Setup the SoftServe plugin.
--- Merges user configuration with defaults, creates the scratch buffer,
--- and registers autocommands and user commands.
---@param user_config? SoftServeConfig User configuration table (optional). Will be merged with defaults.
function M.setup(user_config)
  -- Ensure user_config is a table for validation/merging, even if nil was passed
  local cfg_to_validate = user_config or {}
  local is_valid = validate_config(cfg_to_validate) -- Validate the user input *before* merge

  -- Use deepcopy of defaults to avoid modifying the original M.config table reference
  local defaults_copy = vim.deepcopy(M.config)

  if user_config then -- Only merge if user provided *something*
    if not is_valid then
      vim.notify('SoftServe: Invalid configuration options detected. Using defaults where necessary.',
        vim.log.levels.WARN)
      -- Note: validate_config sets invalid top-level fields in cfg_to_validate to nil
    end
    -- Merge potentially modified (validated, nils inserted) user config into defaults copy.
    M.config = vim.tbl_deep_extend('force', defaults_copy, cfg_to_validate)
  else
    M.config = defaults_copy -- No user config, use the clean defaults copy
  end

  -- Ensure crucial config values have defaults if user provided incomplete/invalid table
  -- These might be redundant if validation + deep_extend handle it, but act as safety net.
  M.config.filetypes = M.config.filetypes or {}
  M.config.window_options = M.config.window_options or {}
  M.config.max_width = M.config.max_width or 120
  M.config.split_command = M.config.split_command or 'vertical rightbelow split'
  M.config.window_cooldown = M.config.window_cooldown or 300

  -- Create the filetype set for efficient lookups
  M.filetypes_set = {}
  for _, ft in ipairs(M.config.filetypes) do
    if type(ft) == 'string' then -- Ensure only strings are added (belt-and-suspenders after validation)
      M.filetypes_set[ft] = true
    end
  end

  -- Create the single shared scratch buffer only once
  -- Check validity in case setup is called multiple times or buffer was deleted externally
  if M.scratch_bufnr == nil or not vim.api.nvim_buf_is_valid(M.scratch_bufnr) then
    M.scratch_bufnr = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer
    vim.bo[M.scratch_bufnr].buftype = 'nofile'
    vim.bo[M.scratch_bufnr].bufhidden = 'hide'             -- Hide when not displayed
    vim.bo[M.scratch_bufnr].swapfile = false
    vim.bo[M.scratch_bufnr].modifiable = false
    -- Setting readonly might interfere with some operations, test if needed. modifiable=false is usually enough.
    -- vim.bo[M.scratch_bufnr].readonly = true
    vim.api.nvim_buf_set_name(M.scratch_bufnr, '[SoftServe]') -- Set name for identification
  end

  -- Create autocommand group
  local augroup = vim.api.nvim_create_augroup('SoftServeManager', { clear = true })

  --- Schedules a check using vim.schedule if not in cooldown.
  local function schedule_check()
    -- Basic debounce: if already in cooldown, rely on next trigger rather than scheduling again
    if not is_in_cooldown() then
      vim.schedule(M.check_and_update)
    end
  end

  -- Trigger checks on relevant events
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    group = augroup,
    callback = schedule_check,
    desc = 'Check SoftServe on buffer/window enter',
  })

  vim.api.nvim_create_autocmd('VimResized', {
    group = augroup,
    callback = function()
      -- Use defer_fn for resize as it can fire rapidly; a small delay is often good.
      vim.defer_fn(M.check_and_update, 100) -- Delay 100ms
    end,
    desc = 'Check SoftServe on editor resize',
  })

  -- Only create FileType autocmd if there are filetypes configured
  if #M.config.filetypes > 0 then
    vim.api.nvim_create_autocmd('FileType', {
      group = augroup,
      pattern = M.config.filetypes, -- Use table directly for pattern (Neovim >= 0.7)
      callback = schedule_check,
      desc = 'Check SoftServe when filetype is set to a managed type',
    })
  end

  vim.api.nvim_create_autocmd('TabEnter', {
    group = augroup,
    callback = function()
      -- Delay slightly on tab enter as window layout might still be settling
      vim.defer_fn(M.check_and_update, 50) -- Delay 50ms
    end,
    desc = 'Check SoftServe on tab enter',
  })

  -- Handle cleanup when windows associated with managed buffers are closed
  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup,
    pattern = '*', -- Needs pattern '*' to get window ID in args.match
    callback = function(args)
      ---@diagnostic disable-next-line: param-type-mismatch
      local closed_win_id = tonumber(args.match) -- args.match is the winid as a string
      if not closed_win_id then
        return
      end

      local bufnr_to_cleanup = nil
      -- Find which managed buffer this window belonged to
      for bnr, info in pairs(M.managed_buffers) do
        -- Check if the closed window was either the content or the split window we track
        if info.content_win == closed_win_id or info.split_win == closed_win_id then
          bufnr_to_cleanup = bnr
          break
        end
      end

      if bufnr_to_cleanup then
        -- If the *content* window was closed, remove the management.
        -- If the *split* window was closed (e.g., by user manually), also remove management.
        -- remove_managed_split handles cooldown registration and ensures the *other* window is closed if needed/possible.
        remove_managed_split(bufnr_to_cleanup)
      end
    end,
    desc = 'Clean up SoftServe state when a managed window is closed',
  })

  -- Handle cleanup when a managed buffer is wiped out
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = augroup,
    pattern = '*', -- Check all buffer wipeouts
    callback = function(args)
      ---@diagnostic disable-next-line: param-type-mismatch
      local wiped_bufnr = tonumber(args.buf) -- args.buf is buffer number
      if not wiped_bufnr then
        return
      end

      -- If the wiped buffer was managed, clean up its state
      if M.managed_buffers[wiped_bufnr] then
        -- remove_managed_split handles cooldown registration.
        remove_managed_split(wiped_bufnr)
      end
    end,
    desc = 'Clean up SoftServe state when a managed buffer is wiped out',
  })

  -- Create user commands for manual control
  vim.api.nvim_create_user_command('SoftServeEnable', function()
    -- Manually trigger a check/update, which will create the split if conditions are met.
    M.check_and_update()
  end, { desc = 'Enable SoftServe management for the current buffer if conditions met (filetype, width)' })

  vim.api.nvim_create_user_command('SoftServeDisable', function()
    -- Manually remove the split for the current buffer
    remove_managed_split(vim.api.nvim_get_current_buf())
  end, { desc = 'Disable SoftServe management and remove split for the current buffer' })

  vim.api.nvim_create_user_command('SoftServeToggle', function()
    local bufnr = vim.api.nvim_get_current_buf()
    if M.managed_buffers[bufnr] then
      remove_managed_split(bufnr)
    else
      -- Only enable if conditions would normally allow it
      M.check_and_update()
    end
  end, { desc = 'Toggle SoftServe management for the current buffer' })

  vim.api.nvim_create_user_command('SoftServeCleanupAll', function()
    M.cleanup_all()
  end, { desc = 'Clean up all SoftServe managed splits across all buffers' })

  vim.api.nvim_create_user_command('SoftServeStatus', function()
    local current_bufnr = vim.api.nvim_get_current_buf()
    local info = M.managed_buffers[current_bufnr]
    local total_width = get_total_width()
    local ft = vim.bo[current_bufnr].filetype
    local should_manage = M.filetypes_set[ft]

    print(string.format('--- SoftServe Status (Buffer %d) ---', current_bufnr))
    print(string.format('Filetype: %s (Managed type: %s)', ft, tostring(should_manage)))
    print(string.format('Total Editor Width: %d, Max Width Config: %d', total_width, M.config.max_width))

    if info then
      local content_valid = vim.api.nvim_win_is_valid(info.content_win)
      local split_valid = vim.api.nvim_win_is_valid(info.split_win)
      print(string.format 'State: MANAGED')
      print(
        string.format(
          '  Content Win: %d (Valid: %s, Width: %s)',
          info.content_win,
          tostring(content_valid),
          content_valid and vim.api.nvim_win_get_width(info.content_win) or 'N/A'
        )
      )
      print(
        string.format(
          '  Split Win: %d (Valid: %s, Buf: %s)',
          info.split_win,
          tostring(split_valid),
          split_valid and vim.api.nvim_win_get_buf(info.split_win) or 'N/A'
        )
      )
    else
      print(string.format 'State: NOT MANAGED')
      local current_winnr = vim.api.nvim_get_current_win()
      local current_win_width = vim.api.nvim_win_get_width(current_winnr)
      print(string.format('Current Window: %d (Width: %d)', current_winnr, current_win_width))
      if should_manage then
        if total_width <= M.config.max_width + 2 then
          print 'Reason: Total width too small.'
        end
        if total_width > M.config.max_width and current_win_width <= M.config.max_width then
          print 'Reason: Current window width not > max_width.'
        end
      end
    end
    print('Managed buffers table:', vim.inspect(M.managed_buffers))
    print('Scratch buffer nr:', M.scratch_bufnr and M.scratch_bufnr or 'nil')
    print('Cooldown active:', is_in_cooldown())
  end, { desc = 'Show SoftServe status and internal state' })

  -- Initial check in case Neovim starts with a managed filetype already open in a wide window
  -- Use schedule to ensure it runs after initial UI setup
  vim.schedule(M.check_and_update)
end

return M
