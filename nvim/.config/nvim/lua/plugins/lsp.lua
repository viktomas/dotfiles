-- vim.lsp.log.set_level('debug')
-- LSP
vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "previous diagnostics" })
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "next diagnostics" })

-- This kemap makes it possible to exit the command-window (:h cmdwin)
-- with <ESC>
vim.api.nvim_create_autocmd({ "CmdwinEnter" }, {
  callback = function()
    vim.keymap.set("n", "<esc>", ":quit<CR>", { buffer = true })
  end,
})

local on_attach = function(client, bufnr)
  local function check_codelens_support()
    local clients = vim.lsp.get_active_clients({ bufnr = 0 })
    for _, c in ipairs(clients) do
      if c.server_capabilities.codeLensProvider then
        return true
      end
    end
    return false
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'CursorHold', 'LspAttach', 'BufEnter' }, {
    buffer = bufnr,
    callback = function()
      if check_codelens_support() then
        vim.lsp.codelens.refresh({ bufnr = 0 })
      end
    end
  })
  -- trigger codelens refresh
  vim.api.nvim_exec_autocmds('User', { pattern = 'LspAttached' })


  -- vim.lsp.completion.enable(true, client.id, bufnr, {
  -- 	autotrigger = true,
  -- 	convert = function(item)
  -- 		return { abbr = item.label:gsub("%b()", "") }
  -- 	end,
  -- })
  local fzf = require("fzf-lua")

  vim.keymap.set("n", "<leader>s", fzf.lsp_document_symbols, { desc = "Open symbol picker" })
  vim.keymap.set("n", "<leader>S", fzf.lsp_live_workspace_symbols, { desc = "Open symbol picker (workspace)" })
  vim.keymap.set("n", "<leader>dd", fzf.diagnostics_document, { desc = "Open diagnostics picker" })
  vim.keymap.set("n", "gD", fzf.lsp_declarations, { desc = "Declaration" })
  vim.keymap.set("n", "gd", fzf.lsp_definitions, { desc = "Definition" })
  vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "LSP Hover" })
  vim.keymap.set("n", "gi", fzf.lsp_implementations, { desc = "Implementation" })
  vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, { desc = "Signature help" })
  -- vim.keymap.set("i", "<C-space>", vim.lsp.completion.get, { desc = "trigger autocompletion" })
  vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, { desc = "Type definition" })
  vim.keymap.set({ "n", "v" }, "<leader>a", vim.lsp.buf.code_action, { desc = "Run code action" })
  vim.keymap.set("n", "gr", fzf.lsp_references, { desc = "references" })
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
-- local capabilities = require("blink.cmp").get_lsp_capabilities()

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


lspconfig.markdown_oxide.setup({
  -- cmd = { vim.fn.expand('~/workspace/tmp/oxide-vim-config/markdown-oxide/target/release/markdown-oxide') }, -- can be removed after https://github.com/Feel-ix-343/markdown-oxide/issues/278 is fixed
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)

    -- daily note command
    vim.api.nvim_create_user_command(
      "Daily",
      function(args)
        local input = args.args

        vim.lsp.buf.execute_command({ command = "jump", arguments = { input } })
      end,
      { desc = 'Open daily note', nargs = "*" }
    )
    vim.api.nvim_create_user_command(
      "Today",
      function() vim.lsp.buf.execute_command({ command = "jump", arguments = { "today" } }) end,
      { desc = 'Open today note', nargs = "*" }
    )
  end,
})
