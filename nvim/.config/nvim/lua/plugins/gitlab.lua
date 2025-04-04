require("gitlab").setup({
	code_suggestions = {
		-- auto_filetypes = { "ruby" },
		ghost_text = {
			enabled = false,
			-- toggle_enabled = "<leader>gle",
			accept_suggestion = "<C-y>",
			-- clear_suggestions = "<C-c>",
			stream = true,
		},
	},
	resource_editing = {
		enabled = true,
	},
	statusline = {
		enabled = false,
	},
})

vim.keymap.set("n", "<leader>tg", "<Plug>(GitLabToggleCodeSuggestions)")
