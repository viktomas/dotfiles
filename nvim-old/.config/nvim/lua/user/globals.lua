-- taken from TJ https://github.com/tjdevries/config_manager/blob/78608334a7803a0de1a08a9a4bd1b03ad2a5eb11/xdg_config/nvim/lua/tj/globals.lua
local ok, plenary_reload = pcall(require, "plenary.reload")
local reloader = require
if ok then
	reloader = plenary_reload.reload_module
end

P = function(v)
	print(vim.inspect(v))
	return v
end

RELOAD = function(...)
	local ok, plenary_reload = pcall(require, "plenary.reload")
	if ok then
		reloader = plenary_reload.reload_module
	end

	return reloader(...)
end

R = function(name)
	RELOAD(name)
	return require(name)
end
