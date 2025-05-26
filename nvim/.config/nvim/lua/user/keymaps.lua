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
-- Copied from https://github.com/nelstrom/vim-visual-star-search
function v_set_search(cmdtype)
  local temp = vim.fn.getreg("s")
  vim.cmd('normal! gv"sy')
  local escaped = vim.fn.escape(vim.fn.getreg("s"), cmdtype .. "\\")
  local replaced = vim.fn.substitute(escaped, [[\n]], [[\n]], "g")
  vim.fn.setreg("/", [[\V]] .. replaced)
  vim.fn.setreg("s", temp)
end

vim.keymap.set("v", "*", [[:<C-u>lua v_set_search('/')<CR>/<C-R>=@/<CR><CR>]], opts)
vim.keymap.set("v", "#", [[:<C-u>lua v_set_search('?')<CR>?<C-R>=@/<CR><CR>]], opts)

-- x doesn't write to default cliboard
vim.keymap.set("n", "x", '"_x', opts)

-- might affect snippets when I introduce them
-- outdated (this keymap is now affecting LuaSnip and I had to move altered version there)
-- don't put replaced code to buffer
vim.keymap.set("v", "p", "pgvygv<ESC>", opts)
