local expand = vim.fn.expand
local options = {
  -- backup
  -- Backup and undo config taken from https://begriffs.com/posts/2019-07-19-history-use-vim.html
  -- Protect changes between writes. Default values of
  -- updatecount (200 keystrokes) and updatetime
  -- (4 seconds) are fine
  backup = false,                          -- Don't keep backups after they were successfully written
  backupcopy = "auto",                     -- use rename-and-write-new method whenever safe
  writebackup = true,                      -- Make a backup when overwriting a file. Delete it afterwards
  swapfile = true,                         -- protect changes between writes by putting them to a swapfile
  directory = expand("~/.vim/swap//"),             -- swap directory
  
  backupdir = expand("~/.vim/backup//"),           -- backup dir - needs patch-8.1.0251

  -- undo
  undofile = true,                         -- persist undo tree for each file
  undodir = expand("~/.vim/undo//"),               -- store undo files in directory

  cursorline = true,                       -- highlight the current line
  number = true,                           -- add line numbers
  ignorecase = true,                       -- make searches case-sensitive only if they contain upper-case characters
  smartcase = true,                        -- see previous line
  -- indentation
  -- https://stackoverflow.com/questions/1878974/redefine-tab-as-4-spaces
  autoindent = true,                       -- copy indent from current line when starting a new line
  smartindent = true,                      -- guess indentation based on opening braces
  tabstop = 4,                             -- insert 4 spaces for a tab
  expandtab = true,                        -- convert tabs to spaces
  shiftwidth = 2,                          -- the number of spaces inserted for each indentation

  spell = true,                            -- enable spelling
  splitbelow = true,                       -- force all horizontal splits to go below current window
  splitright = true,                       -- force all vertical splits to go to the right of current window
  mouse = "a",                             -- allow the mouse to be used in neovim

  termguicolors = true,                    -- set term gui colors (most terminals support this)
  updatetime = 300,                        -- vim waits 300ms after I'm finished editing before it tells plugins to do, good for debouncing linting
  completeopt = { "menuone", "noselect" }, -- show menu even when there's only one option, don't preselect the option, let user manually select it
  cmdheight = 2,                           -- more space in the neovim command line for displaying messages
  showmode = false,                        -- we don't need to see things like -- INSERT -- anymore
  pumheight = 10,                          -- pop up menu height
  numberwidth = 2,                         -- set number column width to 2 {default 4}

  wrap = true,                             -- display lines as one long line
  linebreak = true,                        -- companion to wrap, don't split words
  scrolloff = 8,                           -- minimal number of screen lines to keep above and below the cursor
  sidescrolloff = 8,                       -- minimal number of screen columns either side of cursor if wrap is `false`

  --grep
  grepprg='rg --vimgrep --smart-case --hidden', --copied from https://phelipetls.github.io/posts/extending-vim-with-ripgrep/
  grepformat='%f:%l:%c:%m',
--------------------
  --wildmode = "longest:full"                -- completion mode for files and scripts
  -- showtabline = 2,                         -- always show tabs
  -- timeoutlen = 300,                        -- time to wait for a mapped sequence to complete (in milliseconds)
  -- relativenumber = false,                  -- set relative numbered lines

  -- signcolumn = "yes",                      -- always show the sign column, otherwise it would shift the text each time
  whichwrap = "bs<>[]hl",                  -- which "horizontal" keys are allowed to travel to prev/next line
}

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- vim.opt.shortmess = "ilmnrx"                        -- flags to shorten vim messages, see :help 'shortmess'
-- vim.opt.shortmess:append "c"                           -- don't give |ins-completion-menu| messages
-- vim.opt.wildignore:append({"*/tmp/*","*.so","*.swp","*.zip","*/node_modules/*","*/bower_components/*","*/target/*","*/vendor/*" }) --ignore files in file searches
vim.opt.iskeyword:append "-"                           -- hyphenated words recognized by searches
-- vim.opt.formatoptions:remove({ "c", "r", "o" })        -- don't insert the current comment leader automatically for auto-wrapping comments using 'textwidth', hitting <Enter> in insert mode, or hitting 'o' or 'O' in normal mode.
-- vim.opt.runtimepath:remove("/usr/share/vim/vimfiles")  -- separate vim plugins from neovim in case vim still in use
