return {
	"hrsh7th/nvim-cmp",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"hrsh7th/cmp-nvim-lua",
		"saadparwaiz1/cmp_luasnip",
	},
	config = function()
		-- Setup nvim-cmp.
		local cmp = require("cmp")

		cmp.setup({
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body)
				end,
			},
			window = {
				-- comment these out if you want to use native popup menu
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},
			mapping = cmp.mapping.preset.insert({
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
			}),
			sources = cmp.config.sources({
				{ name = "nvim_lsp" },
				{ name = "luasnip" },
				{ name = "nvim_lua" },
			}, {
				-- TODO: add the buffer, but don't allow fuzzy search and don't pre-select the value
				{ name = "buffer" },
			}),
			experimental = {
				ghost_text = {
					hl_group = "CmpGhostText",
				},
			},
			-- This will avoid autocomplete in string literals
			-- I had to combine the default conditions: https://github.com/hrsh7th/nvim-cmp/blob/5dce1b778b85c717f6614e3f4da45e9f19f54435/lua/cmp/config/default.lua#L10-L16
			-- with checking for string literals
			-- Otherwise telescope would be broken
			--
			-- I added comment to the GitHub issue https://github.com/hrsh7th/nvim-cmp/pull/676#issuecomment-1724981778
			enabled = function()
				local context = require("cmp.config.context")
				local disabled = false
				disabled = disabled or (vim.api.nvim_buf_get_option(0, "buftype") == "prompt")
				disabled = disabled or (vim.fn.reg_recording() ~= "")
				disabled = disabled or (vim.fn.reg_executing() ~= "")
				disabled = disabled or context.in_treesitter_capture("string")
				disabled = disabled or context.in_treesitter_capture("comment")
				return not disabled
			end,
		})

		-- Set configuration for specific filetype.
		cmp.setup.filetype("gitcommit", {
			sources = cmp.config.sources({
				{ name = "cmp_git" }, -- You can specify the `cmp_git` source if you were installed it.
			}, {
				{ name = "buffer" },
			}),
		})

		-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
		cmp.setup.cmdline(":", {
			completion = {
				autocomplete = false,
			},
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "path" },
			}, {
				{ name = "cmdline" },
			}),
		})
	end,
}
