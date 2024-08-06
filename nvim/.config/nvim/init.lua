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

-- Default Config - named dc so I have all plugin names roughly in the same column
local function dc(plugin)
	return { plugin, opts = {}, event = "VeryLazy" }
end

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
	dc("nvim-lualine/lualine.nvim"),

	-- git related plugins
	"tpope/vim-fugitive",

	-- general code helping plugins
	dc("kylechui/nvim-surround"),
	dc("numToStr/Comment.nvim"),
	"tpope/vim-abolish",
	dc("nvimdev/hlsearch.nvim"),
	"tpope/vim-scriptease",
	{
		"HiPhish/rainbow-delimiters.nvim",
		config = function()
			require("rainbow-delimiters.setup").setup()
		end,
	},

	-- TODO: try to install comment.nvim but be careful about conflicting keybidings (:checkhealth which _key)
	-- { 'numToStr/Comment.nvim', opts = {} },
	-- linting with ALE
	-- "dense-analysis/ale",
	{ "dmmulroy/tsc.nvim", opts = {
		flags = {
			noEmit = false,
		},
	}, event = "BufEnter *.ts" },
	dc("windwp/nvim-autopairs"),
	-- Which key shows helpful window to remind me of the keymaps
	{
		"folke/which-key.nvim",
		version = "2.1.0",
		config = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300
			require("which-key").setup({})
		end,
	},
	{ "viktomas/diff-clip.nvim", dev = true },
	-- { "viktomas/ghost.nvim", dev = true, opts = {} },
	{ import = "custom.plugins" },
}, {
	dev = {
		path = "~/workspace/private/nvim/mine",
	},
})

require("user.globals")
