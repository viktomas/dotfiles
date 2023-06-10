return {
	"hrsh7th/vim-vsnip",
	dependencies = { "hrsh7th/cmp-vsnip" },
	config = function()
		local opts = {
			-- silent = true,
			expr = true,
		}

		-- Shorten function name
		local keymap = vim.api.nvim_set_keymap

		--  Expand
		keymap("i", "<C-j>", [[vsnip#expandable()? '<Plug>(vsnip-expand)' : '<C-j>']], opts)
		keymap("s", "<C-j>", [[vsnip#expandable()? '<Plug>(vsnip-expand)' : '<C-j>']], opts)

		-- Expand or jump
		keymap("i", "<C-l>", [[vsnip#available()? '<Plug>(vsnip-expand-or-jump)' : '<C-l>']], opts)
		keymap("s", "<C-l>", [[vsnip#available()? '<Plug>(vsnip-expand-or-jump)' : '<C-l>']], opts)

		-- Jump forward or backward
		keymap("i", "<Tab>", [[vsnip#jumpable(1)? '<Plug>(vsnip-jump-next)' : '<Tab>']], opts)
		keymap("s", "<Tab>", [[vsnip#jumpable(1)? '<Plug>(vsnip-jump-next)' : '<Tab>']], opts)
		keymap("i", "<S-Tab>", [[vsnip#jumpable(-1)? '<Plug>(vsnip-jump-prev)' : '<S-Tab>']], opts)
		keymap("s", "<S-Tab>", [[vsnip#jumpable(-1)? '<Plug>(vsnip-jump-prev)' : '<S-Tab>']], opts)

		-- " Select or cut text to use as $TM_SELECTED_TEXT in the next snippet.
		-- " See https://github.com/hrsh7th/vim-vsnip/pull/50
		-- nmap        s   <Plug>(vsnip-select-text)
		-- xmap        s   <Plug>(vsnip-select-text)
		-- nmap        S   <Plug>(vsnip-cut-text)
		-- xmap        S   <Plug>(vsnip-cut-text)
	end,
}
