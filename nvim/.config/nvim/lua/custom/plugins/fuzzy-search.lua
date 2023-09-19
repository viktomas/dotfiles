return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local telescopeConfig = require("telescope.config")
		local telescopeActions = require("telescope.actions")

		-- grep through hidden files
		-- https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#file-and-text-search-in-hidden-files-and-directories
		-- Clone the default Telescope configuration
		local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }

		-- I want to search in hidden/dot files.
		table.insert(vimgrep_arguments, "--hidden")

		require("telescope").setup({
			defaults = {
				-- `hidden = true` is not supported in text grep commands.
				vimgrep_arguments = vimgrep_arguments,
				mappings = {
					i = {
						["<C-u>"] = false, -- clear the prompt with CTRL-U
						["<esc>"] = telescopeActions.close, --close the picker on ESC
					},
				},
			},
		})

		local builtin = require("telescope.builtin")

		local find_files = function()
			builtin.find_files({ hidden = true })
		end

		local function getVisualSelection()
			vim.cmd('noau normal! "vy"')
			local text = vim.fn.getreg("v")
			vim.fn.setreg("v", {})

			text = string.gsub(text, "\n", "")
			if #text > 0 then
				return text
			else
				return ""
			end
		end

		vim.keymap.set("n", "<leader>f", find_files, { desc = "find files" })
		vim.keymap.set("n", "<leader>;", builtin.resume, { desc = "resume last picker" })
		vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "select buffer" })
		vim.keymap.set("n", "//", builtin.live_grep, { desc = "live grep" })
		vim.keymap.set("v", "//", function()
			local text = getVisualSelection()
			builtin.live_grep({ default_text = text })
		end)
		vim.keymap.set("n", "<F1>", builtin.help_tags, { desc = "search help tags" })
	end,
}
