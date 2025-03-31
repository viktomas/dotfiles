return {
	"pgr0ss/vim-github-url",
	config = function()
		vim.keymap.set({ "n", "v" }, "<leader>c", ":GitHubURL<CR>", { desc = "copy GitLab/GitHub URL" })
	end,
}
