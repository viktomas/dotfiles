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

	completeopt = { "menuone", "noselect", "popup" }, -- prevent the built-in vim.lsp.completion autotrigger from selecting the first item
}

for k, v in pairs(options) do
	vim.opt[k] = v
end
