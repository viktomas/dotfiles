require("user.keymaps")
require("user.options")

require("plugins.minipack").setup({
	verbose = true,
	plugins = {
		{ url = "https://github.com/stevearc/oil.nvim.git", ref = "master" },
		{ url = "https://github.com/folke/tokyonight.nvim.git", ref = "v4.11.0" },
		{
			url = "https://github.com/nvim-treesitter/nvim-treesitter.git",
			ref = "aece1062335a9e856636f5da12d8a06c7615ce8a",
		},
		{ url = "https://github.com/ibhagwan/fzf-lua.git", ref = "a33d382df077563bfd332d9d12942badbd096d2b" },
		{ url = "https://github.com/neovim/nvim-lspconfig.git", ref = "0a1ac55d7d4ec2b2ed9616dfc5406791234d1d2b" },
		{ url = "https://github.com/stevearc/conform.nvim.git", ref = "f9ef25a7ef00267b7d13bfc00b0dea22d78702d5" },
		{ url = "https://github.com/lewis6991/gitsigns.nvim.git", ref = "v1.0.2" },
		{ url = "https://github.com/kylechui/nvim-surround.git", ref = "v3.1.0" },
	},
})

vim.cmd.colorscheme("tokyonight")

require("nvim-surround").setup()

require("plugins.oil")
require("plugins.git")
require("plugins.fuzzy")
require("plugins.lsp")
require("plugins.treesitter")
require("plugins.formatter")
