local opts = { silent = true }

-- Shorten function name
local keymap = vim.keymap.set

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",
--

-- Normal --
-- not needed thanks to 'nvimdev/hlsearch.nvim'
-- keymap("n", "<leader><CR>", ":nohlsearch<CR>", {
-- 	desc = "call :nohlsearch to disable highlighting",
-- })
-- Yank and paste from the system cliboard
keymap({ "n", "v" }, "<leader>y", '"+y', { desc = "yank to clipboard" })
keymap({ "n", "v" }, "<leader>p", '"+p', { desc = "paste from clipboard" })

-- Move around splits with <c-hjkl>
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Resize with arrows
-- keymap("n", "<C-Up>", ":resize -2<CR>", opts)
-- keymap("n", "<C-Down>", ":resize +2<CR>", opts)
-- keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
-- keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap("n", "[b", ":bprevious<CR>", opts)
keymap("n", "]b", ":bnext<CR>", opts)
keymap("n", "[B", ":bfirst<CR>", opts)
keymap("n", "]B", ":blast<CR>", opts)

-- Navigate quickfix
keymap("n", "[q", ":cprev<CR>", opts)
keymap("n", "]q", ":cnext<CR>", opts)

-- Keep cursor in a middle of the screen when I scroll
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)

-- x doesn't write to default cliboard
keymap("n", "x", '"_x', opts)

-- Visual --

-- this keymap is now affecting LuaSnip and I had to move altered version there
-- don't put replaced code to buffer
keymap("v", "p", "pgvygv<ESC>", opts)
--
--  move text and rehighlight -- vim tip_id=224
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
keymap("v", "<A-j>", ":m .+1<CR>==", opts)
keymap("v", "<A-k>", ":m .-2<CR>==", opts)

-- Visual Block --
-- Move text up and down
-- keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
-- keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
-- keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
-- keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Terminal --
-- Better terminal navigation
-- keymap("t", "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
-- keymap("t", "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
-- keymap("t", "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
-- keymap("t", "<C-l>", "<C-\\><C-N><C-w>l", term_opts)

-- This kemap makes it possible to exit the command-window (:h cmdwin)
-- with <ESC>
vim.api.nvim_create_autocmd({ "CmdwinEnter" }, {
	callback = function()
		vim.keymap.set("n", "<esc>", ":quit<CR>", { buffer = true })
	end,
})
