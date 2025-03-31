local options = {
	tabstop = 4, -- insert 4 spaces for a tab
	expandtab = false, -- convert tabs to spaces
	shiftwidth = 4, -- the number of spaces inserted for each indentation
}

for k, v in pairs(options) do
	vim.opt[k] = v
end
