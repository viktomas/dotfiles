return {
	"L3MON4D3/LuaSnip",
	build = (not jit.os:find("Windows"))
			and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build'; make install_jsregexp"
		or nil,
	opts = {
		history = true,
		delete_check_events = "TextChanged",
	},
	keys = {
		{
			"<tab>",
			function()
				local luasnip = require("luasnip")
				if luasnip.expand_or_jumpable() then
					print("expand or jumpable")
					luasnip.expand_or_jump()
				else
					print("not expand_or_jumpable")
					-- feed the normal tab
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
				end
			end,
			mode = { "i", "s" },
		},
		{
			"<s-tab>",
			function()
				require("luasnip").jump(-1)
			end,
			mode = { "i", "s" },
		},
		-- -- <NL> is C-j in lua
		-- { "<NL>", function () require("luasnip").expand() end, mode ="i"},
	},
	config = function()
		require("luasnip.loaders.from_vscode").load({ paths = "./snippets" })
	end,
}
