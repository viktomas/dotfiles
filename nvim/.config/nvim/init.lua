require('user.options')
require('user.keymaps')
require('user.plugins')
require('user.colorscheme')
require('user.tree')
require('user.fuzzy-search')

vim.cmd('source ' .. '~/.config/nvim/old-config.vim')

require('gitsigns').setup()


-- Setup lspconfig.
-- Set up lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()
-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
require('lspconfig')['gopls'].setup {
  capabilities = capabilities
}
require('lspconfig')['tsserver'].setup {
  capabilities = capabilities
}

-- I asked how to solve this in SO: https://stackoverflow.com/a/73290052/606571

vim.keymap.set('n', '<CR>', function()
  -- quickfix window and nofile (e.g. when editing the : command line) need enter to work normally
  if vim.o.buftype == 'quickfix' or vim.bo.buftype == "nofile" then
    return "<CR>"
  else
    return ":nohlsearch<CR>"
  end
end, {expr = true, replace_keycodes = true, desc = "call :nohlsearch to disable highlighting (but only if in file editing)"})
