require("nvim-treesitter").setup({
  ensure_installed = { "lua", "markdown", "markdown_inline", "typescript", "javascript", "go" },
  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,
  -- Automatically install missing parsers when entering buffer
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})

-- Incremental selection via built-in treesitter (nvim 0.12+)
vim.keymap.set("n", "<Enter>", function()
  -- don't activate in command window
  if vim.api.nvim_get_mode().mode == "c" then
    return "<Enter>"
  end
  vim.treesitter.select_node({ mode = "v" })
end, { expr = false })

vim.keymap.set("x", "<Enter>", function()
  vim.treesitter.select_node({ mode = "v" })
end)

vim.keymap.set("x", "<BS>", function()
  vim.treesitter.select_node({ mode = "v", prev = true })
end)
