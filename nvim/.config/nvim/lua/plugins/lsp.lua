-- vim.lsp.log.set_level('debug')

vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = "previous diagnostics" })
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = "next diagnostics" })

-- Exit command-window with <ESC>
vim.api.nvim_create_autocmd("CmdwinEnter", {
  callback = function()
    vim.keymap.set("n", "<esc>", ":quit<CR>", { buffer = true })
  end,
})

-- Keymaps and codelens wired up on every LSP attach
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local bufnr = ev.buf
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    -- CodeLens refresh
    vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'CursorHold', 'BufEnter' }, {
      buffer = bufnr,
      callback = function()
        for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
          if c.server_capabilities.codeLensProvider then
            vim.lsp.codelens.refresh({ bufnr = bufnr })
            break
          end
        end
      end,
    })
    vim.api.nvim_exec_autocmds('User', { pattern = 'LspAttached' })

    local fzf = require("fzf-lua")
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "<leader>s",  fzf.lsp_document_symbols,      "Open symbol picker")
    map("n", "<leader>S",  fzf.lsp_live_workspace_symbols, "Open symbol picker (workspace)")
    map("n", "<leader>dd", fzf.diagnostics_document,       "Open diagnostics picker")
    map("n", "gD",         fzf.lsp_declarations,           "Declaration")
    map("n", "gd",         fzf.lsp_definitions,            "Definition")
    map("n", "K",          vim.lsp.buf.hover,              "LSP Hover")
    map("n", "gi",         fzf.lsp_implementations,        "Implementation")
    map("i", "<C-h>",      vim.lsp.buf.signature_help,     "Signature help")
    map("n", "gy",         vim.lsp.buf.type_definition,    "Type definition")
    map({ "n", "v" }, "<leader>a", vim.lsp.buf.code_action, "Run code action")
    map("n", "gr",         fzf.lsp_references,             "references")
    map("n", "gm",         vim.lsp.buf.implementation,     "implementations")
    map("n", "<leader>r", function()
      -- when rename opens the prompt, press CTRL-F to enter the cmdwin
      -- so normal mode keybindings work there
      local cmdId
      cmdId = vim.api.nvim_create_autocmd("CmdlineEnter", {
        callback = function()
          local key = vim.api.nvim_replace_termcodes("<C-f>", true, false, true)
          vim.api.nvim_feedkeys(key, "c", false)
          vim.api.nvim_feedkeys("0", "n", false)
          cmdId = nil
          return true
        end,
      })
      vim.lsp.buf.rename()
      vim.defer_fn(function()
        if cmdId then vim.api.nvim_del_autocmd(cmdId) end
      end, 500)
    end, "Rename symbol")

    -- ts_ls: buffer-local OrganizeImports command
    if client and client.name == 'ts_ls' then
      vim.api.nvim_buf_create_user_command(bufnr, 'OrganizeImports', function()
        vim.lsp.buf.execute_command({
          command = '_typescript.organizeImports',
          arguments = { vim.api.nvim_buf_get_name(0) },
        })
      end, {})
    end
  end,
})

-- ── Server configurations ────────────────────────────────────────────────────
-- nvim-lspconfig ships default configs; vim.lsp.config merges overrides on top.

vim.lsp.config('gopls', {
  settings = {
    gopls = {
      symbolScope = "workspace", -- don't surface symbols from dependencies
    },
  },
})

vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime   = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
})

-- Custom gowl server (not in nvim-lspconfig — full config required)
vim.lsp.config('gowl', {
  cmd          = { vim.fn.expand('~/private/gowl/gowl') },
  filetypes    = { 'markdown' },
  root_markers = { '.git' },
})

vim.lsp.enable({ 'gopls', 'ts_ls', 'fennel_ls', 'lua_ls', 'gowl' })
