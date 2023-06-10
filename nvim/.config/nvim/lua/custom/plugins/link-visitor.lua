return {
	"xiyaowong/link-visitor.nvim", -- I have to have link visitor because gx stops working without netrw, netrw is disabled to have lir
	config = function()
		local lv = require("link-visitor")
		vim.keymap.set("n", "gx", lv.link_under_cursor, { desc = "link-visitor: link_under_cursor" })
	end,
}
