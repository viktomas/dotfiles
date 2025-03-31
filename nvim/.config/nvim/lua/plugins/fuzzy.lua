local fzf = require("fzf-lua")

vim.keymap.set("n", "<leader>f", fzf.files)
vim.keymap.set("n", "//", fzf.live_grep)
