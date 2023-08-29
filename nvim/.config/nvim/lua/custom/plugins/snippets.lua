return {
	"L3MON4D3/LuaSnip",
	build = (not jit.os:find("Windows"))
			and "echo 'NOTE: jsregexp is optional, so not a big deal if it fails to build'; make install_jsregexp"
		or nil,
	opts = {
		delete_check_events = "TextChanged",
		region_check_events = "InsertEnter",
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
		-- this complicated mapping makes sure that when I'm completing a snippet, I can press p
		-- and the luasnip will write p, instead of using the "_dP
		{
			"p",
			function()
				local luasnip = require("luasnip")

				if luasnip.expand_or_jumpable() then
					-- Send "p"
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("p", true, false, true), "n", false)
				else
					-- Send "_dP"
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"_dP', true, false, true), "n", false)
				end
			end,
			mode = { "v" },
		},
		-- -- <NL> is C-j in lua
		-- { "<NL>", function () require("luasnip").expand() end, mode ="i"},
	},
	config = function(_, opts)
		require("luasnip.loaders.from_vscode").load({ paths = "./snippets" })
		require("luasnip").setup(opts)
	end,
}
