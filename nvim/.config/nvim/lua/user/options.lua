local options = {
	autoindent = true, -- copy indent from current line when starting a new line
	smartindent = true, -- guess indentation based on opening braces
	tabstop = 4, -- insert 4 spaces for a tab
	expandtab = true, -- convert tabs to spaces
	shiftwidth = 2, -- the number of spaces inserted for each indentation

	splitbelow = true, -- force all horizontal splits to go below current window
	splitright = true, -- force all vertical splits to go to the right of current window

	cursorline = true, -- highlight the current line
	number = true, -- add line numbers
	relativenumber = true, -- set relative numbered lines
	ignorecase = true, -- make searches case-sensitive only if they contain upper-case characters
	smartcase = true, -- see previous line

	completeopt = { "menuone", "noinsert", "popup" }, -- prevent the built-in vim.lsp.completion autotrigger from selecting the first item

	-- backup
	-- Backup and undo config taken from https://begriffs.com/posts/2019-07-19-history-use-vim.html
	-- Protect changes between writes. Default values of
	-- updatecount (200 keystrokes) and updatetime
	-- (4 seconds) are fine
	backup = false, -- Don't keep backups after they were successfully written
	backupcopy = "auto", -- use rename-and-write-new method whenever safe
	writebackup = true, -- Make a backup when overwriting a file. Delete it afterwards
	swapfile = true, -- protect changes between writes by putting them to a swapfile
	directory = vim.fn.stdpath("data") .. "/swap//", -- swap directory

	backupdir = vim.fn.stdpath("data") .. "/backup//", -- backup dir - needs patch-8.1.0251

	-- undo
	undofile = true, -- persist undo tree for each file
	undodir = vim.fn.stdpath("data") .. "/undo//", -- store undo files in directory
}

for k, v in pairs(options) do
	vim.opt[k] = v
end
