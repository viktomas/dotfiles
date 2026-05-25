-- Love2D development support
-- Detects Love2D projects (main.lua at root) and:
--   1. Configures lua_ls with Love2D library + LuaJIT runtime
--   2. Provides :LoveRun / :LoveStop commands

local love_job = nil

-- Detect Love2D project: root has main.lua (the Love2D entry point)
local function is_love_project(path)
  return vim.uv.fs_stat(path .. '/main.lua') ~= nil
end

-- Override lua_ls settings for Love2D projects
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= 'lua_ls' then return end

    local root = client.root_dir
    if not root or not is_love_project(root) then return end

    -- Merge Love2D library into workspace settings
    client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
      Lua = {
        runtime = {
          version = 'LuaJIT',
          special = { ['love.filesystem.load'] = 'loadfile' },
        },
        workspace = {
          library = { '${3rd}/love2d/library' },
          checkThirdParty = false,
        },
      },
    })
    client:notify('workspace/didChangeConfiguration', { settings = client.settings })
  end,
})

-- :LoveRun [path] — run Love2D game (defaults to cwd)
vim.api.nvim_create_user_command('LoveRun', function(opts)
  if love_job then
    vim.notify('Love2D is already running (use :LoveStop first)', vim.log.levels.WARN)
    return
  end

  local project_dir = opts.args ~= '' and opts.args or vim.fn.getcwd()

  love_job = vim.system({ 'love', project_dir }, {
    stdout = function(_, data)
      if data then vim.schedule(function() vim.api.nvim_echo({{ data, 'Normal' }}, false, {}) end) end
    end,
    stderr = function(_, data)
      if data then vim.schedule(function() vim.api.nvim_echo({{ data, 'WarningMsg' }}, false, {}) end) end
    end,
  }, function()
    love_job = nil
  end)

  vim.notify('Love2D started: ' .. project_dir)
end, { nargs = '?', complete = 'dir', desc = 'Run Love2D game' })

-- :LoveStop — kill running Love2D process
vim.api.nvim_create_user_command('LoveStop', function()
  if not love_job then
    vim.notify('No Love2D process running', vim.log.levels.WARN)
    return
  end
  love_job:kill('sigterm')
  love_job = nil
  vim.notify('Love2D stopped')
end, { desc = 'Stop Love2D game' })
