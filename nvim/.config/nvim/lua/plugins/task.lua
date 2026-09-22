-- Jump from a `$task-id` reference in a markdown document to that task's
-- zellij session. Task ids are the ones used by the `task` CLI
-- (https://gitlab.com/viktomas/task), e.g. `$markdown-ls-tas-39ym7`.
--
-- Deliberately not an LSP: switching sessions is a side effect on the
-- multiplexer, not a navigation to a location, so there is no Location for
-- textDocument/definition to return.

local M = {}

local TASK_BIN = 'task'

--- Find the `$task-id` token under (or touching) the cursor.
--- Only lowercase/digit/dash tokens count — task ids are slugified, so this
--- keeps `$HOME`, `$PWD`, `$TASK_ID` and friends from being mistaken for ids.
--- @return string|nil id
local function task_id_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col('.')
  for start, id in line:gmatch('()%$([%l%d][%l%d-]*)') do
    -- `start` points at the `$`; the token spans [start, start + #id]
    if col >= start and col <= start + #id then
      return id
    end
  end
  return nil
end

--- Trim + join a command's output streams into one message.
local function output_of(result)
  local parts = {}
  for _, stream in ipairs({ result.stderr, result.stdout }) do
    if stream then
      local trimmed = vim.trim(stream)
      if trimmed ~= '' then
        table.insert(parts, trimmed)
      end
    end
  end
  return table.concat(parts, '\n')
end

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level, { title = 'task' })
  end)
end

--- Switch to the zellij session of the task under the cursor.
function M.switch_to_task_under_cursor()
  local id = task_id_under_cursor()
  if not id then
    notify('no $task-id under the cursor', vim.log.levels.WARN)
    return
  end

  if vim.fn.executable(TASK_BIN) == 0 then
    notify(("`%s` not found in $PATH"):format(TASK_BIN), vim.log.levels.ERROR)
    return
  end

  if not vim.env.ZELLIJ_SESSION_NAME then
    notify(
      ('not inside a zellij session — cannot switch to `%s`'):format(id),
      vim.log.levels.ERROR
    )
    return
  end

  vim.system({ TASK_BIN, 'switch', id }, { text = true }, function(result)
    if result.code == 0 then
      return
    end

    local detail = output_of(result)
    if detail == '' then
      detail = ('exit code %d'):format(result.code)
    end
    notify(('task switch %s failed:\n%s'):format(id, detail), vim.log.levels.ERROR)
  end)
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function(ev)
    vim.keymap.set('n', 'gt', M.switch_to_task_under_cursor, {
      buffer = ev.buf,
      desc = 'Switch to the task under the cursor',
    })
  end,
})

return M
