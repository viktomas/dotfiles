require("user.options")
require("user.keymaps") -- keymaps has to be before lazy so the initialized plugins have correct mappings

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	-- everyone wants these lua functions
	"nvim-lua/plenary.nvim",

	-- color scheme
	{
		"folke/tokyonight.nvim",
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("tokyonight")
		end,
	},

	{ "nvim-lualine/lualine.nvim", opts = {} },

	-- git related plugins
	"tpope/vim-fugitive",

	-- file orientation plugins
	"kylechui/nvim-surround",
	"milkypostman/vim-togglelist",

	-- general code helping plugins
	"tpope/vim-commentary",
	"tpope/vim-abolish",

	-- TODO: try to install comment.nvim but be careful about conflicting keybidings (:checkhealth which _key)
	-- { 'numToStr/Comment.nvim', opts = {} },
	-- linting with ALE
	"dense-analysis/ale",
	{ "dmmulroy/tsc.nvim", opts = {}, event = "BufEnter *.ts" },
	{ "windwp/nvim-autopairs", opts = {} },

	-- Which key shows helpful window to remind me of the keymaps
	{
		"folke/which-key.nvim",
		config = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300
			require("which-key").setup({})
		end,
	},
	{ "viktomas/diff-clip.nvim", dev = true },
	{ import = "custom.plugins" },
}, {
	dev = {
		path = "~/workspace/private/nvim/mine",
	},
})

require("user.globals")
vim.cmd("source " .. "~/.config/nvim/old-config.vim")
