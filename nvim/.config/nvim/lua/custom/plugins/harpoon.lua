return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")

		-- REQUIRED
		harpoon:setup()
		-- REQUIRED
		--
		vim.keymap.set("n", "<leader>j", function()
			harpoon:list():add()
		end)
		vim.keymap.set("n", "<C-e>", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end)

		vim.keymap.set("n", "<C-S-J>", function()
			harpoon:list():select(1)
		end)
		vim.keymap.set("n", "<C-S-K>", function()
			harpoon:list():select(2)
		end)
		vim.keymap.set("n", "<C-S-L>", function()
			harpoon:list():select(3)
		end)
		vim.keymap.set("n", "<C-S-:>", function()
			harpoon:list():select(4)
		end)
	end,
}
