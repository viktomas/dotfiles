local function debounce(ms, fn)
	local timer = vim.uv.new_timer()
	return function(...)
		local argv = { ... }
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end
end
require("lint").linters_by_ft = {
	fish = { "fish" },
	javascript = { "eslint" },
	typescript = { "eslint" },
	markdown = { "vale" },
	sh = { "shellcheck" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
	group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
	callback = debounce(100, function()
		require("lint").try_lint()
	end),
})
