require('user.options')
require('user.keymaps')
require('user.packer')
require('user.colorscheme')
require('user.lir')
require('user.link-visitor')
require('user.fuzzy-search')
require('user.treesitter')
require('user.completion')
require('user.lsp')
require('user.test')
require('user.snippets')
require('user.git')

vim.cmd('source ' .. '~/.config/nvim/old-config.vim')

require('gitsigns').setup()


-- I asked how to solve this in SO: https://stackoverflow.com/a/73290052/606571

vim.keymap.set('n', '<CR>', function()
  -- quickfix window and nofile (e.g. when editing the : command line) need enter to work normally
  if vim.o.buftype == 'quickfix' or vim.bo.buftype == "nofile" then
    return "<CR>"
  else
    return ":nohlsearch<CR>"
  end
end, {expr = true, replace_keycodes = true, desc = "call :nohlsearch to disable highlighting (but only if in file editing)"})
