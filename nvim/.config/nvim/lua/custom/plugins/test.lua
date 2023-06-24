return {
	"vim-test/vim-test",
	config = function()
		local opts = { silent = true }

		vim.g["test#strategy"] = "neovim"
		vim.g["test#javascript#runner"] = "jest"
		vim.keymap.set("n", "<leader>tt", ":TestNearest<CR>", opts)
		vim.keymap.set("n", "<leader>tf", ":TestFile<CR>", opts)
		vim.keymap.set("n", "<leader>ta", ":TestSuite<CR>", opts)
		vim.keymap.set("n", "<leader>tl", ":TestLast<CR>", opts)
		vim.keymap.set("n", "<leader>tg", ":TestVisit<CR>", opts)
		vim.keymap.set("t", "<C-o>", [[<C-\><C-n>]], opts)
	end,
}
