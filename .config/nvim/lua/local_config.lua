local M = {}

local LOCAL_CONFIG_BASE_PATH = vim.fn.expand('~/.local-dotfiles/.config/nvim/lua/local/')

--- Safely loads a Lua table from a file within the local config base path.
--- Returns the loaded table or nil if loading fails or file doesn't exist.
--- @param relative_path string Path relative to LOCAL_CONFIG_BASE_PATH (e.g., "keys/telescope.lua")
--- @return table|nil The loaded table or nil on failure/absence.
local function load_local_table(relative_path)
  local full_path = LOCAL_CONFIG_BASE_PATH .. relative_path
  local loaded_table = nil

  if vim.fn.filereadable(full_path) == 1 then
    -- Use pcall to safely execute dofile. The target file MUST return a table.
    local status_ok, result = pcall(dofile, full_path)
    if status_ok then
      if type(result) == 'table' then
        loaded_table = result
        -- vim.notify("Loaded local config table: " .. full_path, vim.log.levels.DEBUG)
      else
        vim.notify("Local config file did not return a table: " .. full_path, vim.log.levels.WARN)
      end
    else
      vim.notify("Error executing local config file: " .. full_path .. "\n" .. tostring(result), vim.log.levels.ERROR)
    end
  end

  return loaded_table
end

--- Merges a base list of key definitions (table of tables) with definitions
--- loaded from a local override file, if it exists and returns a valid table.
--- Designed specifically for LazyVim-style `keys` tables (lists).
--- @param local_keys_relative_path string The path relative to the local keys directory (e.g., "keys/telescope.lua").
--- @param base_keys table The base list of key definitions.
--- @return table The merged list of key definitions. Returns a copy of base_keys if local file isn't found or is invalid.
function M.maybe_merge_keys(local_keys_relative_path, base_keys)
  -- Start with a deep copy to avoid modifying the original base_keys table.
  local merged_keys = vim.deepcopy(base_keys)
  local local_keys = load_local_table(local_keys_relative_path)

  if local_keys then
    vim.list_extend(merged_keys, local_keys)
    -- vim.notify("Successfully merged local keys from: " .. LOCAL_CONFIG_BASE_PATH .. local_keys_relative_path, vim.log.levels.INFO)
  end

  return merged_keys
end

--- Merges a base options table (map) with options loaded from a local file.
--- Overwrites base keys with local keys in case of conflicts.
--- @param local_opts_relative_path string The path relative to the local opts directory (e.g., "opts/lspconfig.lua").
--- @param base_opts table The base options table (map).
--- @return table The merged options table.
function M.maybe_merge_opts(local_opts_relative_path, base_opts)
  -- Start with a deep copy
  local merged_opts = vim.deepcopy(base_opts)
  local local_opts = load_local_table(local_opts_relative_path)

  if local_opts then
    -- For map-like tables, iterate and overwrite/add keys
    for key, value in pairs(local_opts) do
      merged_opts[key] = value
    end
    vim.notify("Successfully merged local opts from: " .. LOCAL_CONFIG_BASE_PATH .. local_opts_relative_path,
      vim.log.levels.INFO)
  end
  return merged_opts
end

return M
