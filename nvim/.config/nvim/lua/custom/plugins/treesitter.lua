return {
	"nvim-treesitter/nvim-treesitter",
	dependencies = { "HiPhish/nvim-ts-rainbow2" },
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter.configs").setup({
			-- A list of parser names, or "all"
			ensure_installed = { "javascript", "typescript", "ruby", "go" },
			sync_install = false,

			-- Automatically install missing parsers when entering buffer
			auto_install = true,

			highlight = {
				-- `false` will disable the whole extension
				enable = true,

				-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
				-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
				-- Using this option may slow down your editor, and you may see some duplicate highlights.
				-- Instead of true it can also be a list of languages
				additional_vim_regex_highlighting = false,
			},

			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<Enter>",
					node_incremental = "<Enter>",
					scope_incremental = "<c-s>",
					node_decremental = "<BS>",
				},
				-- we don't want this to work in command window, because TS doesn't work there
				is_supported = function()
					local mode = vim.api.nvim_get_mode().mode
					if mode == "c" then
						return false
					end
					return true
				end,
			},

			rainbow = {
				enable = true,
				-- list of languages you want to disable the plugin for
				-- disable = { "jsx", "cpp" },
				-- Which query to use for finding delimiters
				query = "rainbow-parens",
				-- Highlight the entire buffer all at once
				strategy = require("ts-rainbow.strategy.global"),
			},
		})

		-- folding with tree-sitter
		-- -------------------------
		-- https://www.jmaguire.tech/posts/treesitter_folding/
		-- latest telescope workaround from folke https://github.com/nvim-telescope/telescope.nvim/issues/699#issuecomment-1745374486 has been merged and folding works!
		vim.opt.foldmethod = "expr"
		vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
		-- from SO https://stackoverflow.com/questions/8316139/how-to-set-the-default-to-unfolded-when-you-open-a-file
		vim.opt.foldlevelstart = 99

		-- Workaround: vim automatically pushes `noplainbuffer` setting to
		-- https://github.com/neovim/neovim/pull/19419
		vim.api.nvim_create_autocmd({ "Bufenter" }, {
			callback = function()
				vim.opt.spelloptions = "camel"
			end,
		})
	end,
}
