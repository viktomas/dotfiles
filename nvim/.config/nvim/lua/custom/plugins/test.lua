return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/neotest-jest",
		"fredrikaverpil/neotest-golang",
	},
	config = function()
		local opts = { silent = true }
		require("neotest").setup({
			adapters = {
				require("neotest-jest")({
					jestCommand = "npm run test:unit --",
					-- jestConfigFile = "custom.jest.config.ts",
					-- env = { CI = true },
					-- cwd = function(path)
					--   return vim.fn.getcwd()
					-- end,
				}),
				require("neotest-golang"),
			},
		})

		vim.keymap.set("n", "<leader>tt", require("neotest").run.run, opts)
		vim.keymap.set("n", "<leader>tf", function()
			require("neotest").run.run(vim.fn.expand("%"))
		end, opts)
		-- vim.keymap.set("n", "<leader>ta", ":TestSuite<CR>", opts)
		-- vim.keymap.set("n", "<leader>tl", ":TestLast<CR>", opts)
		-- vim.keymap.set("n", "<leader>tg", ":TestVisit<CR>", opts)
		vim.keymap.set("t", "<C-o>", [[<C-\><C-n>]], opts)
	end,
}
