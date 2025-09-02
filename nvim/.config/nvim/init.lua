require("user.keymaps")
require("user.options")
require("user.dev")

require("plugins.minipack").setup({
  verbose = true,
  plugins = {
    { url = "https://github.com/stevearc/oil.nvim.git",     ref = "master" },
    { url = "https://github.com/folke/tokyonight.nvim.git", ref = "v4.11.0" },
    {
      url = "https://github.com/nvim-treesitter/nvim-treesitter.git",
      ref = "aece1062335a9e856636f5da12d8a06c7615ce8a",
    },
    { url = "https://github.com/ibhagwan/fzf-lua.git",                          ref = "a33d382df077563bfd332d9d12942badbd096d2b" },
    { url = "https://github.com/MeanderingProgrammer/render-markdown.nvim.git", ref = "e5c3c500d66e9aaf04c116cdfdb0b040d56a1521" },
    { url = "https://github.com/neovim/nvim-lspconfig.git",                     ref = "0a1ac55d7d4ec2b2ed9616dfc5406791234d1d2b" },
    { url = "https://github.com/stevearc/conform.nvim.git",                     ref = "f9ef25a7ef00267b7d13bfc00b0dea22d78702d5" },
    { url = "https://github.com/lewis6991/gitsigns.nvim.git",                   ref = "8b729e489f1475615dc6c9737da917b3bc163605" }, -- 2025-05-26 latest
    -- { url = "https://github.com/kylechui/nvim-surround.git",  ref = "v3.1.0" },
    -- { url = "https://github.com/windwp/nvim-autopairs.git",   ref = "84a81a7d1f28b381b32acf1e8fe5ff5bef4f7968" },
    { url = "https://github.com/mfussenegger/nvim-lint.git",                    ref = "93b8040115c9114dac1047311763bef275e752dc" },
    {
      url = "https://github.com/echasnovski/mini.completion.git",
      ref = "main",
    },
    { url = "https://github.com/echasnovski/mini.icons.git",    ref = "main" },
    { url = "https://github.com/echasnovski/mini.pairs.git",    ref = "main" },
    { url = "https://github.com/echasnovski/mini.surround.git", ref = "main" },
    { url = "https://github.com/echasnovski/mini.snippets.git", ref = "main" },
    -- { url = "https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim.git", ref = "e840d3f8a3ebf1fafe6b3f2970e3c1906a4de8b0" },
  },
})

vim.cmd.colorscheme("tokyonight")

-- require("nvim-surround").setup()
-- require("nvim-autopairs").setup()

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
