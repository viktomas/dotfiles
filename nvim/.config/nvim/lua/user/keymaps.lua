vim.g.mapleader = " "

vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")

vim.keymap.set({ "n", "v" }, "<leader>y", '"+y')
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p')

--  move text and rehighlight -- vim tip_id=224
vim.keymap.set("v", "<", "<gv", { desc = "reload visual selection on indent change" })
vim.keymap.set("v", ">", ">gv", { desc = "reload visual selection on indent change" })

-- x doesn't write to default cliboard
vim.keymap.set("n", "x", '"_x')

vim.keymap.set({ "n" }, "<leader>yp", function()
	local rel_path = vim.fn.fnamemodify(vim.fn.expand("%"), ":.")
	vim.fn.setreg("+", rel_path)
	print("copied: " .. rel_path)
end, { desc = "yank relative path to clipboard" })

-- allows to search for visually selected text with * and #
vim.keymap.set("v", "*", [[:<C-u>lua v_set_search('/')<CR>/<C-R>=@/<CR><CR>]], opts)
vim.keymap.set("v", "#", [[:<C-u>lua v_set_search('?')<CR>?<C-R>=@/<CR><CR>]], opts)
