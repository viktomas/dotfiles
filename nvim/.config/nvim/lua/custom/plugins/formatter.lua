return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			javascript = { "prettierd" },
			typescript = { "prettierd" },
			go = { "gofmt", "goimports" },
			sh = { "shfmt" },
			yaml = { "yamlfmt" },
			json = { "prettierd", "jq" },
		},
		format_on_save = {
			-- I recommend these options. See :help conform.format for details.
			lsp_format = "fallback",
			timeout_ms = 2000,
		},
	},
}
