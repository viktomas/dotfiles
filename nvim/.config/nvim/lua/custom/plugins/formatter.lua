return {
	"mhartington/formatter.nvim",
	config = function()
		require("formatter").setup({
			-- Enable or disable logging
			logging = true,
			log_level = vim.log.levels.WARN,
			filetype = {
				lua = {
					require("formatter.filetypes.lua").stylua,
				},
				json = {
					-- require("formatter.filetypes.json").prettier,
					require("formatter.filetypes.json").prettierd,
					require("formatter.filetypes.json").jq,
				},
				typescript = {
					require("formatter.filetypes.typescript").prettierd,
				},
				javascript = {
					require("formatter.filetypes.javascript").prettierd,
				},
				go = {
					require("formatter.filetypes.go").gofmt,
					-- require("formatter.filetypes.go").gofumpt,
					require("formatter.filetypes.go").goimports,
				},
				sh = {
					require("formatter.filetypes.sh").shfmt,
				},
				yaml = {
					require("formatter.filetypes.yaml").yamlfmt,
				},

				-- Use the special "*" filetype for defining formatter configurations on
				-- any filetype
				["*"] = {
					-- "formatter.filetypes.any" defines default configurations for any
					-- filetype
					require("formatter.filetypes.any").remove_trailing_whitespace,
				},
			},
		})
		vim.api.nvim_create_augroup("format_on_save", {})
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = "format_on_save",
			pattern = "*",
			callback = function()
				vim.cmd("FormatWrite")
			end,
		})
	end,
}
