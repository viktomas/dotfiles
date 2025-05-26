require("gitsigns").setup({
  on_attach = function(bufnr)
    local gs = require("gitsigns")

    vim.keymap.set({ "n", "v" }, "[g", gs.prev_hunk, { desc = "previous hunk" })
    vim.keymap.set({ "n", "v" }, "]g", gs.next_hunk, { desc = "next hunk" })
    -- vim.keymap.set("n", "<leader>td", gs.toggle_deleted, { desc = "toggle deleted" })
    vim.keymap.set("n", "<leader>hp", gs.preview_hunk, { desc = "preview hunk" })
    vim.keymap.set("n", "<leader>tb", gs.toggle_current_line_blame, { desc = "toggle current line blame" })
    vim.keymap.set("n", "<leader>hD", function()
      gs.diffthis("~")
    end, { desc = "diff this" })
    vim.keymap.set({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>")
  end,
})
