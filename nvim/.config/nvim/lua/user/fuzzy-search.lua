local telescope = require("telescope")
local telescopeConfig = require("telescope.config")
local telescopeActions = require("telescope.actions")

-- grep through hidden files
-- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#file-and-text-search-in-hidden-files-and-directories
-- Clone the default Telescope configuration
local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }

-- I want to search in hidden/dot files.
table.insert(vimgrep_arguments, "--hidden")

require('telescope').setup({
  defaults = {
    -- `hidden = true` is not supported in text grep commands.
    vimgrep_arguments = vimgrep_arguments,
    mappings = {
      i = {
        ["<C-u>"] = false, -- clear the prompt with CTRL-U
        ["<esc>"] = telescopeActions.close, --close the picker on ESC
        -- ctrl+J and ctrl+K to scroll through the selection to match my FZF muscle memory
        ["<C-j>"] = telescopeActions.move_selection_next,
        ["<C-k>"] = telescopeActions.move_selection_previous,
      }
    },
  },
})

local builtin = require('telescope.builtin')

local project_files = function()
  local opts = {} -- define here if you want to define something
  vim.fn.system('git rev-parse --is-inside-work-tree')
  if vim.v.shell_error == 0 then
    builtin.git_files(opts)
  else
    builtin.find_files(opts)
  end
end

vim.keymap.set('n', '<C-p>', project_files, {})
vim.keymap.set('n', 'gb', builtin.buffers, {})
vim.keymap.set('n', '//', builtin.live_grep, {})
vim.keymap.set('n', '<F1>', builtin.help_tags, {})

