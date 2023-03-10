local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


require("lazy").setup({
  -- everyone wants these lua functions
  'nvim-lua/plenary.nvim',

  -- color scheme
  'sainnhe/sonokai',

  'vim-airline/vim-airline',

  -- git related plugins
  'tpope/vim-fugitive',
  "lewis6991/gitsigns.nvim",
  'pgr0ss/vim-github-url',

  -- language related plugins
  {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'},
  'neovim/nvim-lspconfig',

  {
    'tamago324/lir.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
  },
  -- file orientation plugins
  'xiyaowong/link-visitor.nvim', -- I have to have link visitor because gx stops working without netrw, netrw is disabled to have lir
  'justinmk/vim-sneak',
  'tpope/vim-surround',
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.0',
    dependencies = { {'nvim-lua/plenary.nvim'} }
  },
  'milkypostman/vim-togglelist',

  -- Autocomplete
  'hrsh7th/cmp-nvim-lsp',
  'hrsh7th/cmp-buffer',
  'hrsh7th/cmp-path',
  'hrsh7th/cmp-cmdline',
  'hrsh7th/nvim-cmp',
  'hrsh7th/cmp-nvim-lua',

  -- snippets
  'hrsh7th/vim-vsnip',
  'hrsh7th/cmp-vsnip',

  -- general code helping plugins
  'sbdchd/neoformat',
  'tpope/vim-commentary',
  -- linting with ALE
  'dense-analysis/ale',

  'vim-test/vim-test',
  {'prettier/vim-prettier',
    ['do'] = 'yarn install',
    ['for'] = {'javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'vue', 'yaml', 'html'},
  },
  {
    "windwp/nvim-autopairs",
    config = function() require("nvim-autopairs").setup {} end
  },

  -- Hard time to prevent me from using hjkl
  'takac/vim-hardtime',

  -- Which key shows helpful window to remind me of the keymaps
  {
    'folke/which-key.nvim',
    config = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
      require("which-key").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
    end
  }
})

