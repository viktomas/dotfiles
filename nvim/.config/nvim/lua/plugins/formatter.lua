require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    fish = { "fish_indent" },
    fennel = { "fnlfmt" },
    shell = { "shfmt" },
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
  },
  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_format = "fallback",
  },
})
