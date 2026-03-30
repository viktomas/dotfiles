require("user.keymaps")
require("user.options")
require("user.dev")

-- Treesitter hook: run TSUpdate after install/update (must be before vim.pack.add)
vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
  local name, kind = ev.data.spec.name, ev.data.kind
  if name == 'nvim-treesitter' and (kind == 'install' or kind == 'update') then
    if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
    vim.cmd('TSUpdate')
  end
end })

vim.pack.add({
  'https://github.com/stevearc/oil.nvim',
  { src = 'https://github.com/folke/tokyonight.nvim', version = 'v4.11.0' },
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/ibhagwan/fzf-lua',
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/mfussenegger/nvim-lint',
  'https://github.com/echasnovski/mini.completion',
  'https://github.com/echasnovski/mini.icons',
  'https://github.com/echasnovski/mini.pairs',
  'https://github.com/echasnovski/mini.surround',
  'https://github.com/echasnovski/mini.snippets',
})

vim.cmd.colorscheme("tokyonight")

require("mini.icons").setup({})
-- add LSP kind icons to autocompletion
MiniIcons.tweak_lsp_kind()
require("mini.snippets").setup({})
require("mini.completion").setup({})
require("mini.pairs").setup({
  mappings = {
    -- don't add pair if another backtick preceeds
    -- suggested in https://github.com/nvim-mini/mini.nvim/issues/31#issuecomment-2151599842
    ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\`].', register = { cr = false } },
  }
})
require("mini.surround").setup({})
require("plugins.oil")
require("plugins.lint")
require("plugins.git")
require("plugins.fuzzy")
require("plugins.lsp")
require("plugins.treesitter")
require("plugins.formatter")
-- require("plugins.gitlab")
require("permalink")

require('render-markdown').setup({
  completions = { lsp = { enabled = true } },
})

vim.keymap.set("n", "<leader>c", ":GitPermalink<CR>", { noremap = true, silent = true })
