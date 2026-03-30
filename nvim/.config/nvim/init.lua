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
  { src = 'https://github.com/stevearc/oil.nvim',                          version = '0fcc83805ad11cf714a949c98c605ed717e0b83e' },
  { src = 'https://github.com/folke/tokyonight.nvim',                      version = 'v4.11.0' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter',            version = '7caec274fd19c12b55902a5b795100d21531391f' },
  { src = 'https://github.com/ibhagwan/fzf-lua',                           version = 'c9e7b7bfbd01f949164988ee1684035468e1995c' },
  { src = 'https://github.com/MeanderingProgrammer/render-markdown.nvim',  version = 'e3c18ddd27a853f85a6f513a864cf4f2982b9f26' },
  { src = 'https://github.com/neovim/nvim-lspconfig',                      version = '16812abf0e8d8175155f26143a8504e8253e92b0' },
  { src = 'https://github.com/stevearc/conform.nvim',                      version = '086a40dc7ed8242c03be9f47fbcee68699cc2395' },
  { src = 'https://github.com/lewis6991/gitsigns.nvim',                    version = '50c205548d8b037b7ff6378fca6d21146f0b6161' },
  { src = 'https://github.com/mfussenegger/nvim-lint',                     version = '4b03656c09c1561f89b6aa0665c15d292ba9499d' },
  { src = 'https://github.com/echasnovski/mini.completion',                version = '4f94cafdeef02bf3ef9997cd6862658801caa22c' },
  { src = 'https://github.com/echasnovski/mini.icons',                     version = '5b9076dae1bfbe47ba4a14bc8b967cde0ab5d77e' },
  { src = 'https://github.com/echasnovski/mini.pairs',                     version = 'b7fde3719340946feb75017ef9d75edebdeb0566' },
  { src = 'https://github.com/echasnovski/mini.surround',                  version = 'd205d1741d1fcc1f3117b4e839bf00f74ad72fa2' },
  { src = 'https://github.com/echasnovski/mini.snippets',                  version = 'c7a5fd5e767dcc732940f59f2a83c64ea7346a3e' },
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
