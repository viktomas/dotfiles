-- disable netrw 
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- empty setup using defaults
require("nvim-tree").setup({
  hijack_netrw = false,
  view = {
    adaptive_size = true,
    float = {
      enable = true,
    },
  },
})

-- Gets only the folder path from full file path
function getFolderPath(str)
    return str:match("(.*[/\\])")
end

-- Lets vim open the current folder - that triggers lir
function open_lir()
  current_buffer_path = vim.api.nvim_buf_get_name(0)
  current_folder_path = getFolderPath(current_buffer_path)
  vim.cmd(':e '..current_folder_path);
end

vim.keymap.set('n', '-', open_lir, {noremap = true, silent = true, desc = 'run :e on the directory from current buffer'})

local actions = require'lir.actions'
local mark_actions = require 'lir.mark.actions'
local clipboard_actions = require'lir.clipboard.actions'

require'lir'.setup {
  show_hidden_files = true,
  ignore = {}, -- { ".DS_Store" "node_modules" } etc.
  devicons_enable = true,
  mappings = {
    ['<CR>']  = actions.edit,
    ['<C-s>'] = actions.split,
    ['<C-v>'] = actions.vsplit,
    ['<C-t>'] = actions.tabedit,

    ['-']     = actions.up,
    ['q']     = actions.quit,

    ['d']     = actions.mkdir,
    ['%']     = actions.newfile,
    ['R']     = actions.rename,
    ['@']     = actions.cd,
    ['Y']     = actions.yank_path,
    ['.']     = actions.toggle_show_hidden,
    ['D']     = actions.delete,

    ['J'] = function()
      mark_actions.toggle_mark()
      vim.cmd('normal! j')
    end,
    ['C'] = clipboard_actions.copy,
    ['X'] = clipboard_actions.cut,
    ['P'] = clipboard_actions.paste,
  },
  float = {
    winblend = 0,
    curdir_window = {
      enable = false,
      highlight_dirname = false
    },

    -- -- You can define a function that returns a table to be passed as the third
    -- -- argument of nvim_open_win().
    -- win_opts = function()
    --   local width = math.floor(vim.o.columns * 0.8)
    --   local height = math.floor(vim.o.lines * 0.8)
    --   return {
    --     border = {
    --       "+", "─", "+", "│", "+", "─", "+", "│",
    --     },
    --     width = width,
    --     height = height,
    --     row = 1,
    --     col = math.floor((vim.o.columns - width) / 2),
    --   }
    -- end,
  },
  hide_cursor = true,
  on_init = function()
    -- use visual mode
    vim.api.nvim_buf_set_keymap(
      0,
      "x",
      "J",
      ':<C-u>lua require"lir.mark.actions".toggle_mark("v")<CR>',
      { noremap = true, silent = true }
    )

    -- echo cwd
    vim.api.nvim_echo({ { vim.fn.expand("%:p"), "Normal" } }, false, {})
  end,
}

