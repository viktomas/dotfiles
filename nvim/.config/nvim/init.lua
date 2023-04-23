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
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'tokyonight'
    end,
  },

  {'nvim-lualine/lualine.nvim', opts = {}},

  -- git related plugins
  'tpope/vim-fugitive',

  -- file orientation plugins
  'justinmk/vim-sneak',
  'tpope/vim-surround',
  'milkypostman/vim-togglelist',

  -- general code helping plugins
  'sbdchd/neoformat',
  'tpope/vim-commentary',
  -- TODO: try to install comment.nvim but be careful about conflicting keybidings (:checkhealth which _key)
  -- { 'numToStr/Comment.nvim', opts = {} },
  -- linting with ALE
  'dense-analysis/ale',

  {'prettier/vim-prettier',
    ['do'] = 'yarn install',
    ['for'] = {'javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'vue', 'yaml', 'html'},
  },
  { "windwp/nvim-autopairs", opts = {} },

  -- Which key shows helpful window to remind me of the keymaps
  {
    'folke/which-key.nvim',
    config = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
      require("which-key").setup({})
    end
  },
  { import = 'custom.plugins' },
})

vim.cmd('source ' .. '~/.config/nvim/old-config.vim')
