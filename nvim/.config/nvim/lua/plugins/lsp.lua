-- LSP
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "previous diagnostics" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "next diagnostics" })

local on_attach = function(client, bufnr)
	vim.lsp.completion.enable(true, client.id, bufnr, {
		autotrigger = true,
		convert = function(item)
			return { abbr = item.label:gsub("%b()", "") }
		end,
	})
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Declaration" })
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Definition" })
	vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "LSP Hover" })
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Implementation" })
	vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, { desc = "Signature help" })
	vim.keymap.set("i", "<C-space>", vim.lsp.completion.get, { desc = "trigger autocompletion" })
	vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, { desc = "Type definition" })
	vim.keymap.set({ "n", "v" }, "<leader>a", vim.lsp.buf.code_action, { desc = "Run code action" })
	vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "references" })
	vim.keymap.set("n", "gm", vim.lsp.buf.implementation, { desc = "implementations" })
	vim.keymap.set("n", "<leader>r", function()
		-- when rename opens the prompt, this autocommand will trigger
		-- it will "press" CTRL-F to enter the command-line window `:h cmdwin`
		-- in this window I can use normal mode keybindings
		local cmdId
		cmdId = vim.api.nvim_create_autocmd({ "CmdlineEnter" }, {
			callback = function()
				local key = vim.api.nvim_replace_termcodes("<C-f>", true, false, true)
				vim.api.nvim_feedkeys(key, "c", false)
				vim.api.nvim_feedkeys("0", "n", false)
				-- autocmd was triggered and so we can remove the ID and return true to delete the autocmd
				cmdId = nil
				return true
			end,
		})
		vim.lsp.buf.rename()
		-- if LPS couldn't trigger rename on the symbol, clear the autocmd
		vim.defer_fn(function()
			-- the cmdId is not nil only if the LSP failed to rename
			if cmdId then
				vim.api.nvim_del_autocmd(cmdId)
			end
		end, 500)
	end, { desc = "Rename symbol" })
end

-- local capabilities = require("cmp_nvim_lsp").default_capabilities()

local lspconfig = require("lspconfig")
lspconfig["gopls"].setup({
	-- capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		gopls = {
			symbolScope = "workspace",
		}, -- when I search for symbols, I don't want to see dependencies
	},
})
lspconfig["ts_ls"].setup({
	-- capabilities = capabilities,
	on_attach = on_attach,
})
lspconfig["fennel_ls"].setup({
	-- capabilities = capabilities,
	on_attach = on_attach,
})
-- lspconfig["harper_ls"].setup({
-- 	settings = {
-- 		["harper-ls"] = {
-- 			linters = {
-- 				SentenceCapitalization = false,
-- 				-- SpellCheck = false,
-- 			},
-- 		},
-- 	},
-- })
lspconfig["lua_ls"].setup({
	-- capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { "vim" },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false, -- this line disables messages about adding libraries to work environment
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = {
				enable = false,
			},
		},
	},
})
