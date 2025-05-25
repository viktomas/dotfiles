local fzf = require("fzf-lua")

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
vim.keymap.set("n", "gh", fzf.helptags)
