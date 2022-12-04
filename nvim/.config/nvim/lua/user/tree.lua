-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- empty setup using defaults
require("nvim-tree").setup({
  remove_keymaps = {
		'-',  -- the dash usually means moving current dir one level up but I want it to toggle the view (see keymap bellow)
  },
  view = {
    adaptive_size = true,
    float = {
      enable = true,
    },
  },
})

vim.keymap.set('n', '-', ":NvimTreeFindFileToggle<CR>", {noremap = true, silent = true})

