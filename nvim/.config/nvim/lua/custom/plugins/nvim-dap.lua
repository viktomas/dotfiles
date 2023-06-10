return {
	"mfussenegger/nvim-dap",
	config = function()
		vim.keymap.set("n", "<leader>db", require("dap").toggle_breakpoint, { desc = "toggle breakpoint" })
		vim.keymap.set("n", "<leader>dc", require("dap").continue, { desc = "Debug: Continue" })
		vim.keymap.set("n", "<leader>do", require("dap").step_over, { desc = "Debug: Step Over" })
		vim.keymap.set("n", "<leader>di", require("dap").step_into, { desc = "Debug: Step Into" })
		vim.keymap.set("n", "<leader>dr", require("dap").repl.open, { desc = "Debug: Open REPL" })
	end,
}
