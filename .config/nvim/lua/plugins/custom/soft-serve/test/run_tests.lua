#!/usr/bin/env lua

-- test/run_tests.lua
-- Script to run SoftServe tests

local function print_header(text)
  local line = string.rep("-", 60)
  print("\n" .. line)
  print(text)
  print(line)
end

-- Define the command to run tests
local function build_test_command()
  local nvim_cmd = "nvim"
  local plenary_path = "--cmd 'set rtp+=deps/plenary.nvim/'"
  local plugin_path = "--cmd 'set rtp+=./'" -- Add the plugin directory to runtime path
  local headless = "--headless"
  local verbose = "-V1"                     -- Add some verbosity for debugging
  local test_file = "-c 'lua require(\"plenary.test_harness\").test_directory(\"test/\", {sequential = true})'"
  local exit = "-c 'qa!'"

  return table.concat({ nvim_cmd, plenary_path, plugin_path, headless, verbose, test_file, exit }, " ")
end

-- Check for dependencies
print_header("Checking dependencies")

local dependencies = {
  ["plenary.nvim"] = "deps/plenary.nvim"
}

local missing_deps = {}
for dep_name, dep_path in pairs(dependencies) do
  local handle = io.popen("ls -la " .. dep_path .. " 2>/dev/null")
  local result = handle:read("*a")
  handle:close()

  if result:match("No such file or directory") then
    table.insert(missing_deps, dep_name)
  else
    print("✓ Found " .. dep_name)
  end
end

if #missing_deps > 0 then
  print("\nMissing dependencies:")
  for _, dep in ipairs(missing_deps) do
    print("  - " .. dep)
  end

  print("\nPlease install missing dependencies:")
  print("mkdir -p deps")
  print("git clone https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim")
  os.exit(1)
end

-- Check plugin structure
print_header("Checking plugin structure")

local function check_file_exists(file_path)
  local f = io.open(file_path, "r")
  if f then
    f:close()
    print("✓ Found " .. file_path)
    return true
  else
    print("✗ Missing " .. file_path)
    return false
  end
end

local plugin_file = "lua/soft-serve/init.lua"
if not check_file_exists(plugin_file) then
  print("\nWarning: Plugin file not found at expected location.")
  print("Make sure your plugin is structured as expected (lua/soft-serve/init.lua).")
  print("Tests may fail if the plugin cannot be found.")
end

-- Run the tests
print_header("Running SoftServe tests")

local cmd = build_test_command()
print("Executing: " .. cmd)
print("")

os.execute(cmd)
