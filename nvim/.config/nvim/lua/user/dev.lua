local reload = function(name)
	package.loaded[name] = nil
	return require(name)
end

vim.api.nvim_create_user_command("DevReload", function()
	reload("permalink")
	print("reloaded!")
end, {})

vim.keymap.set("n", "<leader>hr", ":DevReload<CR>")
