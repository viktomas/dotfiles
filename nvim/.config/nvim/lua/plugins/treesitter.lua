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
-- `an` selects parent node, `in` selects child node
vim.keymap.set("n", "<Enter>", "van", { remap = true, desc = "Select treesitter node" })
vim.keymap.set("x", "<Enter>", "an", { remap = true, desc = "Expand to parent treesitter node" })
vim.keymap.set("x", "<BS>", "in", { remap = true, desc = "Shrink to child treesitter node" })
