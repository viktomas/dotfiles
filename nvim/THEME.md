# The theme

Implementation: `.config/nvim/lua/user/theme.lua`, wired up at the top of
`init.lua`. Query overrides in `.config/nvim/after/queries/`. Testing tools:
the `nvim-theme` skill (`pi/.pi/agent/skills/nvim-theme/`).

Go and TypeScript buffers are painted by an **attention-based grayscale theme**
layered on top of tokyonight. Every other filetype (lua, markdown, fennel, …)
keeps the colorscheme untouched.

**Current state: `presets.attention` — grayscale tiers, neutral surfaces matched
to the terminal background, identity on a cursor-driven layer, in two variants
(`dark` by default, `light` via `:ThemeVariant`).**

> **Rule for every future change: both variants, or it is not done.** The theme
> is one set of rules over two surface pairs (§2.1). A tier, a surface or a
> palette entry is only finished when it has been *measured* on both — see §9.
> The ramp is written in blend fractions but specified in ΔE, and the same
> fraction lands at a different ΔE against a different background.

---

## 1. The idea

Colour *how much attention a token deserves*, not *what it is*. Concretely, four
commitments:

1. **Everything starts blank.** Tokens are opted back in one rule at a time, so
   every colour on screen is there because its absence was missed.
2. **Scaffolding recedes.** Punctuation, keywords, operators and builtins are
   dimmed, because you never go looking for `{`, `:=`, `string` or `err`.
3. **Identifiers and calls get nothing.** They are ~75% of the tokens; colouring
   them is colouring everything, which is colouring nothing.
4. **Hue is not part of the theme.** Diagnostics, diffs, git signs and search
   keep it. An error is then the only coloured thing on the screen.

Where it comes from, and the sources that disagree productively:

| Idea | Source |
|---|---|
| "If everything is highlighted, nothing is highlighted." Don't colour variables and calls. | [tonsky](https://tonsky.me/blog/syntax-highlighting/) |
| Colour by attention tier: emphasise definitions and control-flow exits; dim keywords and punctuation. | [hank.bond](https://hank.bond/posts/highlighting-my-code-based-on-how-much-i-care/) |
| Many colours make reading "slightly less automatic and slightly more conscious". | [Åkesson](https://www.linusakesson.net/programming/syntaxhighlighting/) |
| Colour is a *wasted* channel, not a wrong one — use dynamic overlays instead of a static token map. | [Hillel Wayne](https://buttondown.com/hillelwayne/archive/syntax-highlighting-is-a-waste-of-an-information/) |
| Differentiate with contrast and weight; reserve hue for diagnostics, diffs, search. | [zenbones](https://github.com/zenbones-theme/zenbones.nvim), [monotone.nvim](https://github.com/Lokaltog/monotone.nvim) |

The research is thin and mostly about novices: Sarkar 2015 (n=10, eye-tracked)
found a completion-time benefit that **decayed with experience**; Hannebauer 2018
(n=390 novices) found **no** correctness benefit, concluding highlighting
"squanders a feedback channel from the IDE to the programmer". Nobody has tested
fewer colours vs more, or attention tiers at all. So this is a preference, built
to be falsifiable one step at a time — not a finding.

---

## 2. Surfaces

```lua
theme.background = "#282c34"   -- ghostty's default background
theme.foreground = "#c5c8c6"   -- Tomorrow Night fg, the neutral gray fish uses
```

Two reasons these are pinned rather than inherited from tokyonight:

- **The terminal must match.** tokyonight-moon paints `#222436`, a blue-violet;
  ghostty's default (`ghostty +show-config --default`) is `#282c34`. Side by side
  with fish, nvim was a visibly bluer, darker rectangle inside the terminal. Now
  the editor, the shell and zellij share one background.
- **A blue-tinted `Normal` makes a "grayscale" theme quietly not grayscale.** The
  entire ramp is derived from `Normal`'s foreground, so a neutral fg is what makes
  the no-hue claim literally true.

`surfaces()` derives every chrome colour from those two by blending, so there is
one knob and no palette to maintain:

| group | derivation |
|---|---|
| `NormalFloat`, `FloatBorder`, `TabLine`, `StatusLineNC`, `Folded` | bg + 5% fg |
| `Pmenu` | bg + 6% |
| `CursorLine`, `CursorColumn`, `ColorColumn` | bg + 7% |
| `StatusLine` | bg + 9% |
| `LspReference*` | bg + 13% |
| `TabLineSel` | bg + 14% |
| `Visual`, `PmenuSel` | bg + 18% |
| `WinSeparator` | bg + 20% |
| `MatchParen` | bg + 26% (plus bold) |
| `LineNr` | fg → bg 68% |
| `DiagnosticUnnecessary` | fg → bg 62% (the dimmest thing on screen) |

Everything hue-bearing — diagnostics, diff, git signs, search — is deliberately
**not** touched and stays tokyonight's.

One consequence to know about: `Normal` changes for *every* filetype, but
tokyonight's own group definitions do not. So in lua or markdown a capture that
tokyonight links to its foreground still paints `#c8d3f5` (bluish) next to a
`Normal` of `#c5c8c6`. Unnoticeable in practice, and the alternative — rewriting
tokyonight's groups — is a colorscheme fork.

### 2.1 Variants

Because every colour in the theme is *derived* from that pair, a variant is just
a different pair plus the recalibration it forces:

```lua
theme.variants.dark  = { background = "#282c34", foreground = "#c5c8c6" }
theme.variants.light = { background = "#ffffff", foreground = "#4d4d4c", tiers = …, palette = … }
```

The light pair is ghostty's bundled **Tomorrow** theme
(`/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Tomorrow`) — the
light sibling of the Tomorrow Night palette fish uses, so the same "editor,
shell and zellij share one surface" argument holds on both sides. Switching:

```vim
:ThemeVariant          " toggle
:ThemeVariant light    " or pick one
```

```lua
theme.setup({ rules = theme.presets.attention, variant = "light" })
```

`set_variant()` rebuilds the tier table (always from the defaults, never from the
previous merge, so toggling is lossless), swaps the hue palette, sets
`vim.o.background` — *before* reloading the colorscheme, since that is the only
thing tokyonight looks at to pick its light side — and repaints.

Two things the light variant does **not** restate:

- **Surfaces.** The same `up()` fractions land within ΔE 1.5 of their dark
  counterparts (measured), because the two pairs have a similar fg↔bg distance:
  ΔE 63 dark, ΔE 67 light. `up(0.07)` is ΔL 5.0 on `#282c34` and ΔL 4.2 on
  white. One set of fractions, two variants.
- **Hue-bearing groups.** Diagnostics, diff, git signs and search stay the
  colorscheme's, which is what `vim.o.background` is set for.

What it *must* restate is the ramp — §3.1.

### 2.2 Switching everything at once

One command flips ghostty, zellij, fish and every *already-open* nvim:

```fish
osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
```

Nothing is broadcast to PIDs. The chain is **DEC private mode 2031**, the
"terminal colour scheme changed" notification:

1. **ghostty** (`ghostty/.config/ghostty/config.ghostty`) follows the macOS
   appearance via `theme = light:tomas-light,dark:tomas-dark`
   (`ghostty/.config/ghostty/themes/`, the same two palettes as §2.1). Open
   windows repaint, and ghostty emits a 2031 notification. `ghostty +show-config`
   aside, the terminal-only path is to rewrite the theme line and
   `kill -SIGUSR2 (pgrep -x ghostty)`; a config reload emits 2031 too.
2. **zellij** ≥ 0.44.2 answers/relays 2031 into every pane and swaps
   `theme_dark` / `theme_light` (both must be set, else the static `theme`
   wins). Manual: `zellij action toggle-theme`.
3. **fish** ≥ 4.3 learns the terminal background from OSC 11, subscribes to
   2031, and re-applies the `[light]` / `[dark]` section of
   `fish/.config/fish/themes/tomas.theme` whenever `$fish_terminal_color_theme`
   changes — in shells that are already running. This is why the old
   `conf.d/fish_frozen_theme.fish` had to go: those were *globals*, they shadow
   everything and never update. `fish_config theme save` is the same trap with
   universals; `fish_config theme choose tomas` in `config.fish` is the live one.
4. **nvim** ≥ 0.11 re-queries OSC 11 on 2031 and writes `'background'`.
5. **pi** (the coding agent TUI, which syntax-highlights code blocks) enables
   2031 and repaints live — but only when its theme setting is the
   `lightTheme/darkTheme` form. `pi/.pi/agent/settings.json` therefore says
   `"theme": "light/dark"`; a plain `"dark"` pins it and pi never even sends
   `CSI ?2031h`.

So `'background'` is the single source of truth for which variant is live, and
the theme *follows* it instead of owning it:

- `setup()` takes the starting variant from `vim.o.background` (the TUI has
   already set it from the terminal by the time user config runs) unless
   `variant =` pins one.
- An `OptionSet` / `background` autocommand maps a terminal-driven change onto
  `set_variant`.
- `set_variant()` writes `vim.o.background` only when it actually differs, under
  a `switching` guard so its own write does not re-enter through `OptionSet`.

That last point is not an optimisation, it is the whole trick. Neovim keeps its
OSC 11 autocommand only if `'background'` was not set by a *sourced script*: at
`VimEnter` it deletes the handler when `nvim_get_option_info2('background').was_set`
and `last_set_sid ~= -8` (`runtime/lua/vim/_core/defaults.lua`). Measured on
0.12.4: a `set` from a sourced file records **sid 3** (kills detection), one from
a command/keymap callback records **sid −8** (keeps it). Hence: no write during
startup, and `:ThemeVariant` — which runs in a command callback — stays safe.
Pinning `variant = "light"` in `init.lua` *does* turn terminal switching off,
which is the point of pinning.

Caveats worth knowing: `OptionSet` never fires during |startup|, so this only
reacts once the session is up; zellij [#5467](https://github.com/zellij-org/zellij/issues/5467)
can mis-deliver a forwarded OSC 11 reply to the wrong pane, so never drive this
by *polling* OSC 11; and zellij's live config reload does not fire for a
symlinked `config.kdl` ([#3992](https://github.com/zellij-org/zellij/issues/3992)),
which stow produces — the `zellij action` theme commands are unaffected.

---

## 3. The tier ramp

Tiers are resolved at apply time and re-applied on `ColorScheme`, so they follow
whatever `Normal` is.

| Tier | Definition | Value | ΔE vs base | Spent on |
|---|---|---|---|---|
| `faint` | fg → bg 0.62 | `#64676b` | 37 | punctuation, brackets, delimiters |
| `dim` | fg → bg 0.42 | `#838689` | 25 | keywords, operators, builtins, modules |
| `muted` | fg → bg 0.20 | `#a6a9a9` | 11 | strings, numbers, booleans |
| `base` | — (no attributes) | `#c5c8c6` | — | identifiers, calls, members, params, types |
| `plain` | base, fg written out | `#c5c8c6` | — | resetting bleed (see §5) |
| `strong` | fg → white 0.55 | `#e5e6e5` | 11 | `return`, `throw`, `defer`, `await` |
| `bold` | white + **bold** | `#ffffff` | 20 + weight | declaration sites |
| `note` | muted + *italic* | `#a6a9a9` | 11 + style | comments you wrote |
| `doc` | dim + *italic* | `#838689` | 25 + style | declaration doc comments |

ΔE is CIE76 distance from `base`; **~10 is roughly the just-noticeable difference**
for text-sized glyphs. That number is the reason this ramp looks the way it does.

### Why the ramp is lopsided

Downwards there is a lot of room: `faint` is ΔE 37 from base, and the background
is further still. Upwards there is almost none — `Normal` is already near-white,
so *pure white* only buys ΔE 20.

This was measured, not guessed, and it killed the previous design. Up to step 3
the theme's loudest tier was `strong` (`#e1e7fa` on tokyonight), used for
**comments**, on the tonsky argument that good comments add to the code. It scored
**ΔE 11** — the weakest contrast in the entire ramp, carrying the signal the theme
cared most about. It read as "the same as code", because it was.

So the ramp now uses three channels, not one:

- **down = luminance.** Plenty of range; this is where recessive tiers live.
- **up = luminance + weight.** `bold` is white *and* bold. Never luminance alone.
- **sideways = italic.** Costs no luminance at all, which is why it carries
  "prose, not code" for comments — a distinction, not a volume change.

And the local-contrast rule: **signals compete with their neighbours, not with the
whole screen.** `strong` is only ΔE 11 from base, which is fine, because it is
spent exclusively on *keywords* — which sit in a field of `dim` siblings, so the
contrast that matters is dim → strong ≈ ΔE 35. The same logic makes
`@string.escape` = `base` work: inside a `muted` string, plain base pops.

### 3.1 The light ramp is lopsided the other way

`blend` is a *fraction*; the ramp is specified in *ΔE*. On `#4d4d4c` over white
the dark fractions overshoot — `faint` becomes ΔE 43, `dim` 30, `muted` 15 — so
the light variant restates them at the fractions that reproduce the dark ladder:

| Tier | dark | ΔE | light | ΔE |
|---|---|---|---|---|
| `faint` | 0.62 → `#64676b` | 37 | 0.53 → `#aaaaaa` | 37 |
| `dim` | 0.42 → `#838689` | 25 | 0.34 → `#898989` | 24 |
| `muted` / `note` | 0.20 → `#a6a9a9` | 11 | 0.15 → `#686868` | 11 |
| `strong` | −0.55 → `#e5e6e5` | 11 | −0.32 → `#343434` | 11 |
| `bold` | −1.00 → `#ffffff` | 20 **+ bold** | −1.00 → `#000000` | 33 **+ bold** |

`bold` is the deliberate exception. The dark ramp is squeezed upwards because
`Normal` is already near-white — pure white buys only ΔE 20. **On white that
constraint does not exist:** `#4d4d4c` is ΔE 33 from black, so the light variant
gets a genuinely loud top of the ramp for free, and declarations use all of it.
The ordering (`base` < `strong` < `bold`) is what the design requires, and it is
preserved; only the headroom differs, and only where it is actually available.

The corollary for the *bottom* of the ramp: the recessive tiers are matched in
ΔE rather than in fraction because they carry the same meaning in both variants
— `faint` must be "scaffolding you never look for", not "as pale as the
background lets me go".

---

## 4. How it works

### Per-language blanking

Neovim's treesitter highlighter looks up `@<capture>.<lang>` and falls back to
`@<capture>` **only if the suffixed group is undefined**
(`runtime/lua/vim/treesitter/highlighter.lua`, `get_hl_from_capture`). So
`@keyword.go = {}` blanks keywords for Go alone and leaves lua alone. `theme.langs`
lists the languages to blank; `theme.filetypes` the filetypes for LSP tokens.

### LSP semantic tokens are three families

`runtime/lua/vim/lsp/semantic_tokens.lua:707-710` applies **three** groups per
token, at increasing priority:

| priority | group |
|---|---|
| 0 | `@lsp.type.<type>.<ft>` |
| 1 | `@lsp.mod.<mod>.<ft>` |
| 2 | `@lsp.typemod.<type>.<mod>.<ft>` |

All three must be blanked. Blanking only the first — as this config did for
months — leaves the colorscheme painting the higher-priority typemod groups:
tokyonight defines `@lsp.typemod.*.defaultLibrary`
(`lua/tokyonight/groups/semantic_tokens.lua:34-50`), which is why `Object`,
`Array`, `JSON` and `Record` were once the *only* coloured tokens on screen — in
the one place the design said hue must never appear.

### Rule lookup inherits up the hierarchy

`@keyword.conditional.ternary` → `@keyword.conditional` → `@keyword` → blank,
mirroring neovim's own `@`-group fallback. A broad rule covers a family; a
specific one overrides it, including *downwards*: `["@function.call"] = "base"`
cancels the bold inherited from `@function`. Two things this catches:

- `@keyword.return` / `@keyword.coroutine` used to have no rule of their own, so
  they rendered at base — *brighter* than the dim keywords around them.
- `@function.builtin` inherits `@function`, which made `make` / `len` / `append` /
  `panic` bold, the loudest tier in the theme. It is pinned to `dim`.

### Custom captures / query overrides

- `after/queries/ecma/highlights.scm` — `((template_substitution) @embedded.code)`
  so `${...}` can be reset (see §5). Priority is deliberately **not** raised, so
  captures nested deeper still win and `??` / brackets keep their own tiers.
- `after/queries/go/highlights.scm` — promotes doc comments on
  `method_declaration` to `@comment.documentation`. nvim-treesitter does this for
  functions, types, consts and vars but not methods; harmless while all comments
  shared a colour, visible the moment they stopped.

---

## 5. The trap: a blank group is not a reset

`{}` sets no attributes. That is what makes backgrounds compose (`Visual`,
`CursorLine`, `Search` layer cleanly on top) — but it also means **a
lower-priority extmark can supply the foreground**. Any blank capture stacked on
a coloured one inherits that colour.

Two live cases, both fixed:

- **Template interpolations.** `(template_string) @string` spans the whole
  literal, and nvim-treesitter marks the interpolation `(template_substitution)
  @none` — but `@none` is *ignored* by the highlighter; it resets nothing. Every
  identifier inside `${...}` therefore rendered as a string. Fixed by capturing
  the substitution as `@embedded.code` and mapping it to `plain` (base with the
  foreground written out).
- **`SCREAMING_CASE` constants.** They match *both* `@type` (starts uppercase) and
  `@constant` in the ecma queries. `@constant` lands on top; leaving it blank let
  `@type`'s colour bleed through and every module constant read as a type. Fixed
  with `["@constant"] = "plain"`.

> Diagnostic for the whole class: `:Inspect` the token and look for a **second,
> larger** capture. If the winning capture is blank, the colour is coming from the
> one underneath it.

This is also why `base` must stay the plain `Normal` foreground: if `base` were
made *dimmer* than `Normal`, every capture with no rule at all would render
brighter than the tokens the theme deliberately puts at base.

---

## 6. The dynamic layer

`theme.dynamic()` — the answer to what the static theme gives up. Identity and
nesting are not encoded in colour; they are shown **where the cursor is**, the
moment you stop moving:

- `document_highlight` on `CursorHold` for any LSP that supports it (250 ms),
  cleared on `CursorMoved`. `LspReference*` is a background at bg + 13%, no hue.
- `MatchParen` as a background at bg + 26% plus bold.

This is Wayne's "syntax highlighting wastes an information channel" argument made
concrete: information appears when you are looking for it instead of permanently,
which is what lets the static theme stay quiet.

---

## 7. Presets

Each builds on the previous. **Live with a step for at least a day before adding
the next** — that is the entire point of starting blank. Swap in `init.lua`:

```lua
local theme = require("user.theme")
theme.setup({ rules = theme.presets.attention })
```

| Preset | What it adds |
|---|---|
| `blank` | nothing at all; pure monochrome, Rob Pike mode |
| `scaffolding` | subtractive only: punctuation `faint`, keywords/operators/builtins `dim` |
| `foreign` | the "not code" tier: comments italic-recessive, literals `muted`, escapes `base` |
| `attention` | **current** — declarations white+bold, control-flow exits `strong`, bleed fixes |
| `fish` | same tiers, hue from my fish palette instead of luminance (see §8) |

Presets are plain tables of `capture -> tier`, so mix freely:

```lua
theme.setup({
  rules = vim.tbl_extend("force", theme.presets.attention, {
    ["@type"] = "strong",      -- try a tier for TS types
  }),
  tiers = { dim = { blend = 0.5 } },   -- widen/narrow the ramp (BOTH variants)
  variant = "light",                   -- or :ThemeVariant at runtime
  background = false,                  -- keep the colorscheme's background
  dynamic = { updatetime = 400 },      -- or dynamic = false
})
```

Rules and presets are **variant-independent by construction** — they name tiers,
never colours — which is the property that makes a second variant cheap. `tiers`
passed to `setup()` wins over the variant's own table and therefore applies to
both: if an override is only right on one background, put it in
`theme.variants.<name>.tiers` instead.

### `presets.foreign` — why comments are recessive

The earlier design made comments the loudest thing on screen (tonsky: "good
comments ADD to the code… they are important"). Measuring killed it: "loudest"
was ΔE 11. Comments are now `muted` + *italic* — italic makes them unmistakably
not code at no luminance cost, and leaves the loud end of the ramp for the one
signal that can use it.

It also buys a distinction the loud version could not express: **doc comments and
in-body comments are different tiers.** In Go every top-level declaration comment
is `@comment.documentation` (`doc`, dim+italic) while a note *inside* a function
body is `@comment` (`note`, muted+italic) — so boilerplate `// Foo does foo.`
recedes and the comment that actually explains something is one step brighter.

---

## 8. Why not colour

`presets.fish` exists, works, and is documented here because it looks good: the
palette is my fish theme (Tomorrow Night, from
`fish/.config/fish/conf.d/fish_frozen_theme.fish`; the light variant swaps in
plain Tomorrow, with both yellows darkened because `#f0c674` is unreadable on
white), so the shell and the editor would spend hue on the same meanings — yellow comments, green strings, cyan
escapes, purple definitions, aqua control flow, blue types, and red reserved for
diagnostics.

It was tried for real and reverted for one concrete reason: **a purple-bold
declaration is darker than the plain identifier next to it.** `#b294bb` has lower
luminance than `#c5c8c6`, so `autoOnByClock` *receded* exactly where it was
supposed to pop, while `pi.ui.setStatus` — deliberately unstyled — read louder.
Hue gives you distinguishability, but the attention axis needs *ordering*, and an
arbitrary palette does not order by luminance. Making it order correctly means
picking colours by luminance, at which point the hue is decoration.

The secondary cost: it broke commitment 4. With hue in the theme, `note` yellow
sits next to `DiagnosticWarn` `#ffc777` and `flow` aqua next to `DiagnosticHint`
`#4fd6be` — errors stop being the only coloured thing on the screen.

If it ever comes back, the fix is to pick the palette entries by luminance rather
than by fish's semantics, i.e. only for tiers *at or below* base, and keep
white+bold for declarations.

---

## 9. Verifying

Never judge this by looking at it. Use the `nvim-theme` skill:

```bash
S=~/.pi/agent/skills/nvim-theme/scripts
$S/tiers.sh > /tmp/tiers.json
$S/capture.sh file.ts 30 > /tmp/pane.txt
$S/decode.py /tmp/pane.txt --tiers /tmp/tiers.json --rows 1-25
$S/decode.py /tmp/pane.txt --tiers /tmp/tiers.json --summary   # palette + share + dE
```

**Then do it again for the other variant** — a change is not verified until both
are, and "it looked fine" is not verification on either:

```bash
echo 'require("user.theme").set_variant("light")' > /tmp/light.lua
$S/tiers.sh light > /tmp/tiers-light.json
$S/capture.sh file.ts 30 /tmp/light.lua > /tmp/pane-light.txt
$S/decode.py /tmp/pane-light.txt --tiers /tmp/tiers-light.json --summary
```

The two summaries must show the **same ΔE ladder** (§3.1), not the same blend
fractions. Unowned hexes in the light summary that are chrome, not bugs:
`#c6c6c6` is `LineNr` (fg → bg 68%) and `#717170` is `StatusLine`'s fg (20%).

`capture.sh` runs the real nvim in tmux with the real LSP attached and dumps the
pane with its escape sequences; `decode.py` turns those into per-token tier names.
A raw hex in the output means no tier owns that token, which is usually the bug.

Single group, no rendering:

```bash
nvim --headless -c 'lua print(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("@function.typescript")), "fg#"))' -c q
```

Use `synIDtrans(hlID(...))`, not `nvim_get_hl`: `@`-prefixed groups have an
automatic parent fallback that only `hlID` resolves, and that fallback is exactly
where the colorscheme leaks in — `nvim_get_hl` reports such a group as empty while
the screen shows a colour.

`:Inspect` on a token shows the captures and the treesitter *language* that
applied (`tsx` and `typescript` are different languages; both must be in
`theme.langs`).

---

## 10. Still open

- **`strong` on `return` in Go.** `if err != nil { return err }` is everywhere, so
  every error branch lights up. Either exactly right (error paths *are* the
  boundaries of a function) or noise. `@keyword.coroutine` (`go`, `defer`) is the
  safe half of that rule; drop `@keyword.return` first if it grates.
- **TypeScript types.** Currently `base`. They are sparse, deliberate and in
  predictable positions, which is the argument for giving them a tier;
  `["@type"] = "strong"` is the experiment, and it competes with control-flow
  exits for the same tier.
- **JSX.** `@tag` / `@tag.attribute` is arguably a foreign grammar embedded in the
  host — the same argument that earns strings their treatment.
- **Injected languages.** SQL or markdown inside a template literal is a different
  treesitter language, so it is not in `theme.langs` and renders in full
  tokyonight colour. Not yet decided whether that is a bug or a feature.
- **Nothing switches the variant automatically.** `:ThemeVariant` is manual, and
  ghostty is still pinned to its dark default — so the light variant currently
  means a light editor inside a dark terminal. The fix is one line of ghostty
  config (`theme = light:Tomorrow,dark:...`, which follows the macOS appearance)
  plus something that tells a running nvim; deliberately not done until the light
  variant has been lived with.
- **`bold` at ΔE 33 on light.** Three times the dark variant's top-of-ramp
  contrast (§3.1). Justified by the headroom being real, but it is the one place
  the two variants are not the same theme; watch whether declarations shout.

---

## Log

- **step 1 (blank), started.** _(never filled in)_
- **steps 2+3 (`foreign`) applied together** without an evaluation period on
  blank, at request.
- **fix while applying step 2:** rule lookup now inherits up the capture
  hierarchy; broad rules cover whole families.
- **step 3 measured, not eyeballed** (screenshot decoded per character cell, then
  re-verified by decoding SGR from `tmux capture-pane -e`). Everything the preset
  promised was on screen — plus three things nobody had noticed: the
  `@lsp.typemod` hue leak, the template-literal bleed, and `strong` scoring ΔE 11.
- **step 5 (`presets.fish`) applied and reverted.** Hue from the fish palette
  fixed visibility but broke ordering: purple-bold declarations read *quieter*
  than unstyled identifiers. Kept as a preset, documented in §8.
- **now: `presets.attention` in grayscale**, with white+bold declarations, italic
  comments, neutral terminal-matched surfaces, and the dynamic layer enabled. The
  three bleed/leak fixes are in `presets.attention` and `after/queries/`.
- **light variant added.** Surfaces from ghostty's `Tomorrow`; the recessive
  tiers restated at the fractions that reproduce the dark ΔE ladder, since the
  dark fractions overshoot to ΔE 43/30/15 on white. Verified by decoding a real
  light capture: the ladder matches and the only hue on screen is diagnostics.
  Surfaces were measured and left shared (within ΔE 1.5).
- **next:** live with it. The three things to watch are aqua-free `return`
  (`strong` on every error branch), whether TS types need a tier, and whether
  light `bold` (ΔE 33) is too loud.
