return {
	"stevearc/oil.nvim",
	opts = {
		view_options = {
			show_hidden = true,
		},
	},
	-- Optional dependencies
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function(_, opts)
		-- disable netrw
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		require("oil").setup(opts)
		vim.keymap.set("n", "-", require("oil").open, { desc = "Open parent directory" })
	end,
}
