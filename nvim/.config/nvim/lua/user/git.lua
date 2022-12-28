local opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap
keymap("n", "]g", ":Gitsigns next_hunk<CR>", opts)
keymap("n", "[g", ":Gitsigns prev_hunk<CR>", opts)
keymap("v", "]g", ":Gitsigns next_hunk<CR>", opts)
keymap("v", "[g", ":Gitsigns prev_hunk<CR>", opts)
