local fzf = require("fzf-lua")

local function getVisualSelection()
  vim.cmd('noau normal! "vy"')
  local text = vim.fn.getreg("v")
  vim.fn.setreg("v", {})

  text = string.gsub(text, "\n", "")
  if #text > 0 then
    return text
  else
    return ""
  end
end

fzf.setup({
  files = {
    hidden = true,
  },
  grep = {
    hidden = true,
  },
})

vim.keymap.set("n", "<leader>f", fzf.files)
vim.keymap.set("n", "<leader>gs", fzf.git_status)
vim.keymap.set("n", "<leader>;", fzf.resume)
vim.keymap.set("n", "//", fzf.live_grep)
vim.keymap.set("v", "//", function()
  local text = getVisualSelection()
  fzf.live_grep({ query = text })
end)
vim.keymap.set("n", "gh", fzf.helptags)
