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
