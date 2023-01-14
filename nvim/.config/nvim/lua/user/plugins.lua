local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

return require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  -- everyone wants these lua functions
  use 'nvim-lua/plenary.nvim'

  -- color scheme
  use 'morhetz/gruvbox'
  use 'sainnhe/sonokai'
  use 'vim-airline/vim-airline'

  -- git related plugins
  use 'tpope/vim-fugitive'
  use "lewis6991/gitsigns.nvim"

  -- language related plugins
  -- use 'sheerun/vim-polyglot'
  use {'nvim-treesitter/nvim-treesitter', ['do'] = ':TSUpdate'}
  use 'neovim/nvim-lspconfig'


  -- file orientation plugins
  use {
    'nvim-tree/nvim-tree.lua',
    requires = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
    tag = 'nightly' -- optional, updated every week. (see issue #1193)
  }
  use { 
    'tamago324/lir.nvim',
    requires = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
  }
  use 'justinmk/vim-sneak'
  use 'tpope/vim-surround'
  use {
    'nvim-telescope/telescope.nvim', tag = '0.1.0',
    requires = { {'nvim-lua/plenary.nvim'} }
  }
  use 'milkypostman/vim-togglelist'

  -- Autocomplete
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-path'
  use 'hrsh7th/cmp-cmdline'
  use 'hrsh7th/nvim-cmp'

  -- snippets
  use 'hrsh7th/vim-vsnip'
  use 'hrsh7th/cmp-vsnip'
  use "rafamadriz/friendly-snippets"

  -- general code helping plugins
  use 'sbdchd/neoformat'
  use 'tpope/vim-commentary'
  use 'w0rp/ale'
  use 'vim-test/vim-test'
  use {'prettier/vim-prettier',
    ['do'] = 'yarn install',
    ['for'] = {'javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'vue', 'yaml', 'html'},
  }
  use {
    "windwp/nvim-autopairs",
    config = function() require("nvim-autopairs").setup {} end
  }

  -- Hard time to prevent me from using hjkl
  use 'takac/vim-hardtime'

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
