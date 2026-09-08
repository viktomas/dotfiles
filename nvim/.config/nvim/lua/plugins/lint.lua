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
local lint = require("lint")

-- markdownlint-cli2 reads its config from the process cwd only, so point it at
-- the project root that holds the config (mirrors CI's `markdownlint-cli2` job).
local markdownlint_configs = {
	".markdownlint-cli2.yaml",
	".markdownlint-cli2.jsonc",
	".markdownlint-cli2.cjs",
	".markdownlint.yaml",
	".markdownlint.json",
}

-- vale errors out (exit code 2) when it cannot find a config file, so only run
-- it in projects that have one.
local vale_configs = { ".vale.ini", "_vale.ini" }

lint.linters_by_ft = {
	fish = { "fish" },
	javascript = { "eslint" },
	typescript = { "eslint" },
	-- markdown linters are run conditionally in the autocmd below
	sh = { "shellcheck" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
	group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
	callback = debounce(100, function()
		lint.try_lint()

		if vim.bo.filetype == "markdown" then
			local markdownlint_root = vim.fs.root(0, markdownlint_configs)
			if markdownlint_root then
				lint.linters["markdownlint-cli2"].cwd = markdownlint_root
				lint.try_lint("markdownlint-cli2")
			end

			if vim.fs.root(0, vale_configs) then
				lint.try_lint("vale")
			end
		end
	end),
})
