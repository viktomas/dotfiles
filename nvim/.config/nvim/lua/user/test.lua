local opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap

keymap("n", "<leader>t", ":TestNearest<CR>", opts)
keymap("n", "<leader>T", ":TestFile<CR>", opts)
keymap("n", "<leader>a", ":TestSuite<CR>", opts)
keymap("n", "<leader>l", ":TestLast<CR>", opts)
keymap("n", "<leader>g", ":TestVisit<CR>", opts)
