local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.config/nvim/plugged')

-- color scheme
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'

-- git related plugins
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

-- language related plugins
Plug 'sheerun/vim-polyglot'
Plug('nvim-treesitter/nvim-treesitter', {['do'] = ':TSUpdate'})
Plug 'neovim/nvim-lspconfig'


-- file orientation plugins
Plug 'tpope/vim-vinegar'
Plug 'justinmk/vim-sneak'
Plug 'tpope/vim-surround'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'milkypostman/vim-togglelist'

-- Autocomplete
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/vim-vsnip'

-- general code helping plugins
Plug 'tpope/vim-commentary'
Plug 'w0rp/ale'
Plug ('prettier/vim-prettier', {
  ['do'] = 'yarn install',
  ['for'] = {'javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'vue', 'yaml', 'html'},
})

vim.call('plug#end')

vim.cmd('source ' .. '~/.config/nvim/old-config.vim')



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
