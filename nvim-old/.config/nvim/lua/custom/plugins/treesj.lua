return {
	"Wansmer/treesj",
	keys = { "<space>tm" },
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("treesj").setup()
		vim.keymap.set("n", "<leader>tm", require("treesj").toggle)
	end,
}
