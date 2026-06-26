# Fennel + love2d LSP (hover docs, completions)

Per-plugin Fennel editing setup lives in `nvim/.config/nvim/lua/plugins/fennel.lua`
(structural editing + Conjure REPL). This doc covers the LSP side: getting
`K` hover docs and completions for love2d in `.fnl` files.

## How `K` works

`K` is mapped to `vim.lsp.buf.hover` on `LspAttach` (see `lua/plugins/lsp.lua`).
The docs you see come from whatever LSP is attached:

- Lua files (`.lua`) → `lua_ls`, which loads the love2d library (`love2d.lua`).
- Fennel files (`.fnl`) → `fennel_ls`.

Conjure's own `K` doc lookup is disabled in `fennel.lua`
(`vim.g["conjure#mapping#doc_word"] = false`) so LSP hover wins in lisp buffers.

`fennel_ls` is enabled in `lua/plugins/lsp.lua` via `vim.lsp.enable({ ..., 'fennel_ls', ... })`.

## One-time machine setup

`fennel_ls` is only enabled in nvim — the binary and the love2d docset are not
checked into dotfiles, so install them once per machine.

1. Install the language server (binary name must be `fennel-ls`):
   ```sh
   brew install fennel-ls
   ```

2. Install the love2d docset (technomancy/fennel-ls-docsets):
   ```sh
   mkdir -p ~/.local/share/fennel-ls/docsets
   curl -o ~/.local/share/fennel-ls/docsets/love2d.lua \
        https://p.hagelb.org/docsets/love2d.lua
   ```
   The docset filename (`love2d`) is the name referenced by the project config
   below. Other docsets are listed on http://wiki.fennel-lang.org/LanguageServer.

## Per-project setup

`fennel-ls` only attaches when it finds a `flsproject.fnl` (nvim-lspconfig uses
it as the `root_dir` marker), and that file is what loads the docset. Add one to
the root of each love2d project (commit it — collaborators benefit):

```fennel
{:fennel-path "./?.fnl;./?/init.fnl"
 :lua-version "lua5.1"
 :libraries {:love2d true}
 :extra-globals "love VIRTUAL_WIDTH VIRTUAL_HEIGHT"}
```

- `:libraries {:love2d true}` loads `~/.local/share/fennel-ls/docsets/love2d.lua`.
- `:extra-globals` silences false "unknown global" diagnostics — list `love`
  plus any globals the project defines itself.
- `:fennel-path` should match the project's `require` layout.

## Verify

Reopen a `.fnl` file in a project that has `flsproject.fnl` (so `fennel_ls`
attaches), put the cursor on e.g. `love.graphics.draw`, and press `K`.

If nothing happens:
```
:checkhealth lsp          -- is fennel_ls attached?
:LspInfo                  -- root_dir should point at the flsproject.fnl dir
```
Confirm `fennel-ls` is on `PATH` and the docset file exists at the path above.
