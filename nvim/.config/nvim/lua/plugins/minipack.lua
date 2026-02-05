local M = {}

-- Configuration with sensible defaults
local config = {
  pack_dir = vim.fn.stdpath("data") .. "/site/pack/plugins/start",
  plugins = {},
  verbose = false,
}

-- Logger utility with proper levels
local function log(msg, level)
  level = level or "info"
  if config.verbose or level == "error" then
    local prefix = "[miniplug] "
    if level == "error" then
      vim.notify(prefix .. msg, vim.log.levels.ERROR)
    else
      vim.notify(prefix .. msg, vim.log.levels.INFO)
    end
  end
end

-- Execute a shell command with improved error handling
local function execute(cmd)
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    log("Command failed with code " .. exit_code .. ": " .. cmd, "error")
    log(output, "error")
  end

  return output, exit_code
end

-- Extract plugin name from git URL with better pattern matching
local function get_plugin_name(url)
  return url:match("/([^/]+)%.git$") or url:match("/([^/]+)$") or url:match("([^/]+)$")
end

-- Add a plugin to the list with fluent interface
function M.add(url, ref)
  ref = ref or "HEAD"
  local name = get_plugin_name(url)

  if not name then
    log("Could not determine plugin name from URL: " .. url, "error")
    return M
  end

  table.insert(config.plugins, {
    name = name,
    url = url,
    ref = ref,
  })

  return M
end

-- Update a single plugin with better directory handling
local function update_plugin(plugin)
  local plugin_dir = config.pack_dir .. "/" .. plugin.name
  local exists = vim.fn.isdirectory(plugin_dir) == 1

  log("Processing plugin: " .. plugin.name)

  if not exists then
    -- Clone the repository
    log("Cloning " .. plugin.url)
    local _, code = execute("git clone " .. plugin.url .. " " .. plugin_dir)
    if code ~= 0 then
      return false
    end
  end

  -- Use pcall for safer directory operations
  local current_dir = vim.fn.getcwd()
  local ok = pcall(vim.fn.chdir, plugin_dir)
  if not ok then
    log("Failed to change directory to: " .. plugin_dir, "error")
    return false
  end

  -- Fetch latest changes
  log("Fetching updates for " .. plugin.name)
  execute("git fetch --quiet")

  -- Get current commit hash
  local current_hash = execute("git rev-parse HEAD"):gsub("%s+", "")

  -- Get target commit hash with better branch handling
  local target_hash
  local is_branch = plugin.ref == "HEAD" or plugin.ref == "main" or plugin.ref == "master"

  if is_branch then
    local branch = plugin.ref == "HEAD" and "HEAD" or plugin.ref
    target_hash = execute("git rev-parse origin/" .. branch):gsub("%s+", "")
  else
    target_hash = execute("git rev-parse " .. plugin.ref):gsub("%s+", "")
    if target_hash:match("fatal") then
      log("Invalid ref: " .. plugin.ref .. " for plugin " .. plugin.name, "error")
      vim.fn.chdir(current_dir)
      return false
    end
  end

  -- Checkout the target ref if different
  if current_hash ~= target_hash then
    log("Updating " .. plugin.name .. " from " .. current_hash:sub(1, 7) .. " to " .. target_hash:sub(1, 7))
    local _, code = execute("git checkout --quiet " .. target_hash)
    if code ~= 0 then
      vim.fn.chdir(current_dir)
      return false
    end
  else
    log(plugin.name .. " is already at the correct version: " .. current_hash:sub(1, 7))
  end

  -- Go back to the original directory
  vim.fn.chdir(current_dir)
  return true
end

-- Find directories in pack folder that aren't in our managed plugins list
local function find_unmanaged_plugins()
  local unmanaged = {}
  local managed_names = {}

  -- Create a lookup table of managed plugin names
  for _, plugin in ipairs(config.plugins) do
    managed_names[plugin.name] = true
  end

  -- Check if pack directory exists
  if vim.fn.isdirectory(config.pack_dir) ~= 1 then
    return unmanaged
  end

  -- Use vim.fn.glob for more idiomatic directory listing
  local dirs = vim.fn.glob(config.pack_dir .. "/*", false, true)

  -- Process each directory
  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local name = vim.fn.fnamemodify(dir, ":t")
      if name and not managed_names[name] then
        table.insert(unmanaged, name)
      end
    end
  end

  return unmanaged
end

-- Remove a plugin using vim functions
local function remove_plugin(name)
  local plugin_dir = config.pack_dir .. "/" .. name

  if vim.fn.isdirectory(plugin_dir) == 1 then
    log("Removing unmanaged plugin: " .. name)

    -- Use vim's delete() function instead of system rm
    local result = vim.fn.delete(plugin_dir, "rf")
    if result ~= 0 then
      log("Failed to remove directory: " .. plugin_dir, "error")
      return false
    end
    return true
  end

  return true
end

-- Update all plugins with status tracking
function M.update()
  log("Starting plugin update")

  -- Ensure the pack directory exists
  if vim.fn.isdirectory(config.pack_dir) ~= 1 then
    log("Creating plugin directory: " .. config.pack_dir)
    vim.fn.mkdir(config.pack_dir, "p")
  end

  -- Update each plugin
  local success = true
  for _, plugin in ipairs(config.plugins) do
    if not update_plugin(plugin) then
      success = false
    end
  end

  -- Find and remove unmanaged plugins
  local unmanaged = find_unmanaged_plugins()
  for _, name in ipairs(unmanaged) do
    if not remove_plugin(name) then
      success = false
    end
  end

  if success then
    vim.cmd('helptags ALL')     -- update docs
    log("All plugins updated successfully")
  else
    log("Some plugin operations failed", "error")
  end

  return success
end

-- Set configuration with validation
function M.setup(opts)
  opts = opts or {}

  -- Merge configuration
  for k, v in pairs(opts) do
    if k == "plugins" then
      -- Handle plugins separately
    elseif config[k] ~= nil then
      config[k] = v
    end
  end

  -- Process plugins if provided
  if opts.plugins then
    for _, plugin in ipairs(opts.plugins) do
      if type(plugin) == "string" then
        -- Support simple string format
        M.add(plugin)
      elseif type(plugin) == "table" and plugin.url then
        -- Support table format with error handling
        local ok, err = pcall(M.add, plugin.url, plugin.ref)
        if not ok then
          log("Error adding plugin " .. vim.inspect(plugin) .. ": " .. err, "error")
        end
      end
    end
  end

  return M
end

-- List all managed plugins with better formatting
function M.list()
  if #config.plugins == 0 then
    print("[miniplug] No plugins managed")
    return
  end

  print("[miniplug] Managed plugins:")
  for i, plugin in ipairs(config.plugins) do
    print(string.format("%d. %s (%s @ %s)", i, plugin.name, plugin.url, plugin.ref))
  end
end

return M
