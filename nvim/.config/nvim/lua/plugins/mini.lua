require("mini.icons").setup({})
-- vim.g.miniicons_disable = true
vim.api.nvim_create_user_command('DebugCompletionCache', function()
  local resolved_count = vim.tbl_count(require('mini.completion').H.completion.lsp.resolved or {})
  local result_size = 0
  if require('mini.completion').H.completion.lsp.result then
    result_size = vim.inspect(require('mini.completion').H.completion.lsp.result):len()
  end

  print("Resolved cache size: " .. resolved_count .. " entries")
  print("Result cache size: ~" .. math.floor(result_size / 1024) .. "KB")
end, {})
require("mini.snippets").setup({})
require("mini.completion").setup({})
