---
name: nvim-theme
description: Test, verify and explore my neovim theme by measuring what is actually painted on screen - decode real colours per token, compare before/after, build an HTML page of side-by-side options, check contrast. Use whenever changing nvim highlight groups, treesitter captures, tier rules, when a token has the wrong colour, or when choosing between candidate colours. Keywords - theme, highlight, colour, tier, treesitter capture, semantic tokens, compare options, THEME.md.
---

# Testing the neovim theme

The theme lives in `~/.dotfiles/nvim/.config/nvim/lua/user/theme.lua` and is
documented in `~/.dotfiles/nvim/THEME.md`. **Read THEME.md before changing
rules** — the tier ramp is deliberate and measured.

This is a **project skill** (`~/.dotfiles/.pi/skills/`), so it loads when the
agent is running in the dotfiles repo — which is where the theme is edited. The
scripts themselves are path-independent: to capture a file from another repo,
keep working here and point at it, or pass `--cwd` so the LSP gets the right
root.

```bash
S=~/.dotfiles/.pi/skills/nvim-theme/scripts
```

The rule of this skill: **never judge a theme by looking at it.** Every bug ever
found in this theme was found by decoding the screen; none were found by eye.
Run nvim in tmux, dump the pane with its escape sequences, decode them.

## The loop

```bash
S=~/.dotfiles/.pi/skills/nvim-theme/scripts

$S/tiers.sh > /tmp/tiers.json                      # live tier -> colour table
$S/capture.sh path/to/file.ts 30 > /tmp/pane.txt   # real nvim, real LSP, line 30 at top
$S/decode.py /tmp/pane.txt --tiers /tmp/tiers.json --rows 1-25
```

**The theme has two variants (`dark`, `light`) and a change is not verified
until both are.** The ramp is written as blend fractions but calibrated in ΔE,
and the same fraction lands at a different ΔE against a different background —
so a tier that is right on `#282c34` can be wrong on `#ffffff`. Run the loop
twice:

```bash
echo 'require("user.theme").set_variant("light")' > /tmp/light.lua
$S/tiers.sh light > /tmp/tiers-light.json
$S/capture.sh path/to/file.ts 30 /tmp/light.lua > /tmp/pane-light.txt
$S/decode.py /tmp/pane-light.txt --tiers /tmp/tiers-light.json --summary
```

The two `--summary` outputs should show the *same ΔE ladder* (37 / 25 / 11 down,
11 up, plus `bold`), not the same blend fractions. If a light tier's ΔE drifts
from its dark twin, fix it in `theme.variants.light.tiers`, not in `theme.tiers`.

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

## Exploring options: `compare.py`

When the question is *"which of these should I pick?"* rather than *"is this
right?"*, build the page instead of decoding by hand. `compare.py` captures the
same file under N variations **in both variants**, decodes each to SVG, and
emits one self-contained HTML file:

```bash
$S/compare.py scripts/esbuild/helpers.ts --cwd ~/workspace/gl/gitlab-lsp/main \
  "current theme" \
  "hue 110°, C*=10=/tmp/c10.lua" \
  "hue 110°, C*=22=/tmp/c22.lua" \
  --title "String tint" --note "L* held constant; only chroma varies." \
  --out /tmp/strings.html --keep /tmp/strings-work --open
```

Each positional argument is `LABEL=lua-file`; the split is on the **last** `=`
and only when the tail ends in `.lua`, so labels may contain `=` (`C*=10`). A
bare label with no lua file is the untouched theme and becomes the **A/B
reference** — always pass it first.

What the page gives you that a screenshot does not:

- **Hover to A/B.** Hovering any card swaps it for the reference, same file,
  same rows, same window — the only way to judge a ΔE-10 difference honestly.
- **Both variants, one toggle** (`v`). THEME.md's rule is that a change is not
  done until both are measured, so the tool refuses to make it optional: every
  option is captured twice, and the light captures are where the surprises are.
- **A computed readout, not a declared one.** Each card diffs its palette
  against the reference's and reports the colours the change *actually*
  introduced, their share of the window and their ΔE from base. If a card says
  "no palette change", the lua did nothing — that is a real failure mode and it
  is invisible in a screenshot.

The option lua files are the same runtime hook as below, so they should handle
both variants themselves — `compare.py` pins the variant with `set_variant()`
before sourcing them:

```lua
local t = require("user.theme")
local tint = { dark = "#a9aa97", light = "#686b45" }   -- per variant, always
t.tiers.quote = { fg = tint[t.variant] }
t.rules["@string"] = "quote"
t.apply()
```

Cost and flags: ~20 s per capture, 2–3 in parallel (`--jobs`). `--keep DIR`
stores the panes and **reuses them next run**, so iterating on labels, notes or
rows is instant; `--refresh` forces re-capture. `--line` / `--rows` / `--cols`
pick the window. A half-drawn pane is detected (fewer than 60% of rows painted)
and retried with a longer wait — under parallel load the fixed `CAPTURE_WAIT`
fails *silently*, producing a short dump that decodes into a plausible page with
three colours in it.

### Equal ΔE is not equal appearance across variants

The thing the page was built to catch, and did on its first use: a string tint at
C\*=10 reads clearly on `#282c34` and **vanishes on white**, although CIE76 puts
both at ΔE 10 from the grey they replace. CIE76 has no lightness-dependent
chroma term, and perceived colourfulness falls with luminance level, so dark text
on a light background needs roughly **2× the chroma** for the same effect. Match
variants by *appearance in the captures*, not by the number — the same lesson as
THEME.md §3.1, one axis over.

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
$S/capture.sh file.ts 30                 > /tmp/after.txt
```

The same hook is how the light variant is captured: `set_variant("light")` in
that lua file repaints everything at runtime, so no config edit is needed.

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
- `tiers.sh light` and a capture taken *without* `/tmp/light.lua` is the classic
  mismatch: every token then decodes as a raw hex. If the summary is all `?`,
  check that the tier table and the pane came from the same variant.
- Chrome shows up in `--summary` as unowned hexes and that is expected:
  `LineNr` (fg → bg 68%) and `StatusLine`'s fg (fg → bg 20%) are surfaces, not
  tiers. Hue that is *not* a diagnostic or a diff is the thing to chase.
