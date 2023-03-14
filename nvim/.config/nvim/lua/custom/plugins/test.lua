return {
  'vim-test/vim-test',
  config = function()
    local opts = { silent = true }

    vim.keymap.set("n", "<leader>t", ":TestNearest<CR>", opts)
    vim.keymap.set("n", "<leader>T", ":TestFile<CR>", opts)
    vim.keymap.set("n", "<leader>a", ":TestSuite<CR>", opts)
    vim.keymap.set("n", "<leader>l", ":TestLast<CR>", opts)
    vim.keymap.set("n", "<leader>g", ":TestVisit<CR>", opts)
  end
}
