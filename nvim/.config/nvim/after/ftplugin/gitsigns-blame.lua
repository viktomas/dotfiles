-- Open the commit under cursor on the web (GitLab/GitHub)
vim.keymap.set("n", "gx", function()
  local line = vim.api.nvim_get_current_line()
  -- Commit lines: "╺ <sha> <author> <date>" — SHA starts after the marker + space
  -- Continuation lines: "│ <summary>" or "┕ <summary>" — no SHA
  local sha = line:match("[╺┍]%s+(%x+)%s")
  if not sha or #sha < 7 then
    print("No commit SHA on this line — move to a commit header line")
    return
  end

  -- Find the git dir from the source buffer (the non-blame window)
  local git_dir
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "gitsigns-blame" then
      local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":h")
      if dir and dir ~= "" then
        git_dir = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")[1]
        break
      end
    end
  end

  if not git_dir or git_dir == "" then
    print("Could not find git root")
    return
  end

  local remote_url = vim.fn.system("git -C " .. vim.fn.shellescape(git_dir) .. " remote get-url origin"):gsub("\n", "")

  local web_url
  if remote_url:match("^git@") then
    web_url = remote_url:gsub("git@([^:]+):", "https://%1/"):gsub("%.git$", "")
  elseif remote_url:match("^https://") then
    web_url = remote_url:gsub("%.git$", "")
  else
    print("Unsupported remote URL format: " .. remote_url)
    return
  end

  local commit_path = web_url:match("gitlab") and "/-/commit/" or "/commit/"
  local url = web_url .. commit_path .. sha

  vim.ui.open(url)
  print("Opened: " .. url)
end, { buffer = true, desc = "Open commit on web" })

-- Add to the gitsigns blame context menu (<CR>)
vim.cmd([[nmenu <silent> ]GitsignsBlame.Open\ on\ web\ (gx) gx]])
