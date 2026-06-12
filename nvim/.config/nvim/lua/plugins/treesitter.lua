require("nvim-treesitter").setup({})

-- Ensure parsers we care about are installed (the `main` branch ignores
-- `ensure_installed` in setup(), so install explicitly).
local ensure_installed = {
  "lua", "markdown", "markdown_inline", "typescript", "javascript", "go", "fennel",
}
pcall(function()
  require("nvim-treesitter").install(ensure_installed)
end)

-- The `main` branch no longer auto-enables highlighting. Start treesitter
-- highlighting for any buffer whose filetype has a parser available.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local ok = pcall(vim.treesitter.start, args.buf)
    if not ok then
      return
    end
  end,
})

-- Incremental selection via built-in treesitter (nvim 0.12+)
-- `an` selects parent node, `in` selects child node
vim.keymap.set("n", "<Enter>", "van", { remap = true, desc = "Select treesitter node" })
vim.keymap.set("x", "<Enter>", "an", { remap = true, desc = "Expand to parent treesitter node" })
vim.keymap.set("x", "<BS>", "in", { remap = true, desc = "Shrink to child treesitter node" })
