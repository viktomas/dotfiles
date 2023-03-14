require('user.options')
require('user.keymaps') -- keymaps has to be before lazy so the initialized plugins have correct mappings

-- I asked how to solve this in SO: https://stackoverflow.com/a/73290052/606571

vim.keymap.set('n', '<CR>', function()
  -- quickfix window and nofile (e.g. when editing the : command line) need enter to work normally
  if vim.o.buftype == 'quickfix' or vim.bo.buftype == "nofile" then
    return "<CR>"
  else
    return ":nohlsearch<CR>"
  end
end, {expr = true, replace_keycodes = true, desc = "call :nohlsearch to disable highlighting (but only if in file editing)"})

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
  {
    'sainnhe/sonokai',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'sonokai'
    end,
  },

  {'nvim-lualine/lualine.nvim', opts = {}},

  -- git related plugins
  'tpope/vim-fugitive',

  -- file orientation plugins
  'justinmk/vim-sneak',
  'tpope/vim-surround',
  'milkypostman/vim-togglelist',
  {'karb94/neoscroll.nvim', opts = {}},

  -- general code helping plugins
  'sbdchd/neoformat',
  'tpope/vim-commentary',
  -- linting with ALE
  'dense-analysis/ale',

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
  },
  { import = 'custom.plugins' },
})

vim.cmd('source ' .. '~/.config/nvim/old-config.vim')
