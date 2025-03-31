require("gitsigns").setup({
	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns

		vim.keymap.set({ "n", "v" }, "[g", gs.prev_hunk, { desc = "previous hunk" })
		vim.keymap.set({ "n", "v" }, "]g", gs.next_hunk, { desc = "next hunk" })
	end,
})
