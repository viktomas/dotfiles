---
name: nvim-theme
description: Test and verify my neovim theme by measuring what is actually painted on screen - decode real colours per token, compare before/after, check contrast. Use whenever changing nvim highlight groups, treesitter captures, tier rules, or when a token has the wrong colour. Keywords - theme, highlight, colour, tier, treesitter capture, semantic tokens, THEME.md.
---

# Testing the neovim theme

The theme lives in `~/.dotfiles/nvim/.config/nvim/lua/user/theme.lua` and is
documented in `~/.dotfiles/nvim/THEME.md`. **Read THEME.md before changing
rules** — the tier ramp is deliberate and measured.

The rule of this skill: **never judge a theme by looking at it.** Every bug ever
found in this theme was found by decoding the screen; none were found by eye.
Run nvim in tmux, dump the pane with its escape sequences, decode them.

## The loop

```bash
S=~/.pi/agent/skills/nvim-theme/scripts

$S/tiers.sh > /tmp/tiers.json                      # live tier -> colour table
$S/capture.sh path/to/file.ts 30 > /tmp/pane.txt   # real nvim, real LSP, line 30 at top
$S/decode.py /tmp/pane.txt --tiers /tmp/tiers.json --rows 1-25
```

`decode.py` prints every token prefixed with the tier that painted it:

```
   6 [dim]function [bold+B]autoOnByClock[faint]([base]now [dim]= [dim]new [bold+B]Date[faint]()): [dim]boolean [faint]{
   7   [dim]const[base] day [dim]=[base] now[faint].[base]getDay[faint](); [note+I]// 0 = Sun, 6 = Sat
   8   [strong]return[base] day [dim]>= [muted]1 [dim]&&[base] day [dim]<= [muted]5 [faint];
```

`+B` is bold, `+I` italic, a raw hex means "no tier owns this" — which is
usually the bug.

Other views:

```bash
$S/decode.py /tmp/pane.txt --tiers /tmp/tiers.json --summary        # palette + share + dE
$S/decode.py /tmp/pane.txt --tiers /tmp/tiers.json --rows 1-28 --svg /tmp/sample.svg
```

`--summary` is the fastest way to answer "is there hue on screen that should not
be there?" and "is this tier actually distinguishable?" — it prints ΔE (CIE76)
from base, where **~10 is the just-noticeable threshold** for text-sized glyphs.
A tier under ~10 is not a signal, no matter what the intent was.

`--svg` emits the capture as an SVG, exactly as painted — that is what goes into
reports.

## Before / after, without editing the config

Write a lua file that undoes the change at runtime and pass it as the third
argument. Both captures then run the same theme and only the change differs:

```bash
cat > /tmp/before.lua <<'LUA'
local t = require("user.theme")
t.rules["@embedded.code"] = nil   -- put the bug back
t.apply()
LUA
$S/capture.sh file.ts 30 /tmp/before.lua > /tmp/before.txt
$S/capture.sh file.ts 30            > /tmp/after.txt
```

## Checking a single group without rendering anything

```bash
cd ~/.dotfiles && nvim --headless -c 'lua
for _, n in ipairs({ "@function.typescript", "@keyword.lua" }) do
  print(n, vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(n)), "fg#"))
end' -c q
```

Use `synIDtrans(hlID(...))` and **not** `nvim_get_hl`: `@`-prefixed groups have
an automatic parent fallback that only `hlID` resolves, and that fallback is
where the colorscheme leaks in. `nvim_get_hl` reports such a group as empty
while the screen shows a colour.

## Two traps that account for most wrong colours

1. **A blank group is not a reset.** `{}` sets no attributes, so a *lower*
   extmark supplies the foreground. Any blank capture stacked on a coloured one
   inherits that colour (this is how `${...}` interpolations rendered as strings,
   and how `SCREAMING_CASE` constants rendered as types). Diagnose with
   `:Inspect` — if the winning capture is blank, look for a second, *larger*
   capture in the list. Fix with the `plain` tier or a query override in
   `after/queries/`.
2. **LSP semantic tokens are three families, not one.**
   `@lsp.type.<t>.<ft>`, `@lsp.mod.<m>.<ft>` and `@lsp.typemod.<t>.<m>.<ft>` are
   all applied per token at increasing priority. Blanking only the first leaves
   the colorscheme painting the others.

## Notes

- `capture.sh` sleeps `CAPTURE_WAIT` (default 14s) for the LSP to attach and
  send semantic tokens. Shorter waits silently test the treesitter-only theme.
- `CAPTURE_COLS` / `CAPTURE_ROWS` resize the pane; a row in the dump is a screen
  row, so wrapped long lines take more than one.
- Pass filetypes that actually exercise the rules: TypeScript for template
  literals and types, Go for doc comments vs in-body comments and `if err != nil`
  density.
- Test a file the theme does **not** touch too (lua, markdown) — the theme is
  scoped to `theme.langs` / `theme.filetypes` and must leave everything else on
  the colorscheme.
