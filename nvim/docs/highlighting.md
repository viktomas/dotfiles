# Attention-based highlighting (Go / TypeScript)

Implementation: `nvim/.config/nvim/lua/user/highlight.lua`, wired up in `init.lua`.

Go and TypeScript buffers use a **near-blank** theme layered on top of
tokyonight. Every other filetype (Lua, markdown, fennel, …) is untouched.

**Current state: step 3 of the plan below (`presets.foreign`) — scaffolding
dimmed, comments and literals opted back in.**

## Why

Instead of colouring *what a token is* (syntax class), colour *how much
attention it deserves*. The reasoning, and where it comes from:

| Idea | Source |
|---|---|
| "If everything is highlighted, nothing is highlighted." Limit colours to what you can remember. Don't colour variables/calls — they're 75% of the code. | [tonsky, *Everyone is getting syntax highlighting wrong*](https://tonsky.me/blog/syntax-highlighting/) |
| Colour by attention tier, not token class: emphasise comments + definitions + control-flow exits, dim keywords + punctuation. | [hank.bond, *Highlighting my code based on how much I care*](https://hank.bond/posts/highlighting-my-code-based-on-how-much-i-care/) |
| Many colours make reading "slightly less automatic and slightly more conscious; leaving less room in the conscious part of the mind for actually understanding the text." | [Åkesson, *A case against syntax highlighting*](https://www.linusakesson.net/programming/syntaxhighlighting/) |
| Colour is a wasted channel, not a wrong one. What you need depends on the task (writing vs debugging vs review) — so use *dynamic* overlays, not a static token map. | [Hillel Wayne](https://buttondown.com/hillelwayne/archive/syntax-highlighting-is-a-waste-of-an-information/) |
| Differentiate with contrast and weight; **reserve hue exclusively for diagnostics, diffs and search**. | [zenbones](https://github.com/zenbones-theme/zenbones.nvim), [monotone.nvim](https://github.com/Lokaltog/monotone.nvim) |

The last row is the governing rule here: hue is scarce and spent only on things
that are *wrong* or *transient*, so an error is unmissable against uniform text.
Diagnostic, diff and search highlights are deliberately left alone.

### What the research actually says

Thin and mostly about novices. Sarkar 2015 (n=10, eye-tracked): highlighting
improved completion time, but **the effect decayed with experience**; no
fixation differences, just fewer context switches between code and prompt.
Hannebauer 2018 (n=390 novices): **no** correctness benefit, concluding that
highlighting *"squanders a feedback channel from the IDE to the programmer."*
Nobody has tested *more colours vs fewer*, or attention-tier schemes at all.

The honest counterargument: one practitioner who went fully monochrome found it
*cognitively taxing* — "the tiny amount of effort to classify bits of text as
comment or code added up" — and settled on comments + strings only. That is
exactly what step 3 below adds back.

## How it works

Neovim's treesitter highlighter looks up `@<capture>.<lang>` and falls back to
`@<capture>` **only if the suffixed group is undefined**
(`runtime/lua/vim/treesitter/highlighter.lua`, `get_hl_from_capture`).
So defining `@keyword.go = {}` blanks that capture for Go alone.

LSP semantic tokens use `@lsp.type.<type>.<filetype>` (always filetype-suffixed,
see `runtime/lua/vim/lsp/semantic_tokens.lua`), blanked the same way.

Two details that matter:

- Groups are set to `{}` (no attributes) rather than `fg = Normal.fg`. An empty
  group composes correctly under CursorLine / Visual / Search; a forced `fg`
  does not.
- Rule lookup **inherits up the capture hierarchy**, mirroring neovim's own
  `@`-group fallback. `@keyword.conditional.ternary` uses the rule for
  `@keyword.conditional`, else `@keyword`, else blank. So `["@keyword"] = "dim"`
  covers every keyword subcapture, and a more specific rule overrides it —
  including downwards, e.g. `["@function.call"] = "base"` cancels the `bold`
  inherited from `@function`. Without this, unlisted subcaptures rendered at
  base and came out *brighter* than the family they belong to.
- Tier colours are derived from `Normal` at apply time and re-applied on the
  `ColorScheme` autocmd, so switching colorscheme keeps this working.

Verify it is doing what you think:

```
:lua for _,g in ipairs({"@keyword.go","@keyword.lua"}) do
  print(g, vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(g)), "fg#")) end
```

Expect `@keyword.go` blank and `@keyword.lua` coloured. Use `:Inspect` on a
token to see which capture and which treesitter *language* actually applied
(`tsx` and `typescript` are different languages; both are covered).

## Tiers

Attributes are derived by blending `Normal`'s foreground either towards the
background (positive `blend`, recessive) or away from it (negative, brighter).

| Tier | Blend | Effect on tokyonight |
|---|---|---|
| `faint` | 0.62 | `#61677f` |
| `dim` | 0.42 | `#828aa5` |
| `muted` | 0.20 | `#a7b0cf` |
| `base` | — | `#c8d3f5` (plain `Normal`, no attributes) |
| `strong` | -0.45 | `#e1e7fa` |
| `bold` | -0.45 + bold | `#e1e7fa` bold |

## The plan

Each step builds on the previous. **Live with each for at least a day before
adding the next** — that is the entire point of starting blank. Record what
actually hurt in the log at the bottom.

### Step 1 — blank (done)

```lua
highlight.setup({ rules = highlight.presets.blank })
```

Nothing highlighted in Go/TS. Goal is not to keep this forever; it is to find
out *empirically* which absence you actually notice, rather than guessing.

What to pay attention to while living with it:

- Do you misread a comment as live code, or commented-out code as live?
- Do you lose the end of a multi-line string, or miss an unterminated quote?
- Do you have trouble finding where a function *starts* when scanning a file?
- Does nesting/bracket matching get harder, or does indentation carry it?
- Does anything feel *better* — less busy, easier to stay in?

### Step 2 — `presets.scaffolding` (done)

Subtractive only: dim punctuation, operators, keywords, builtins. Nothing gets
brighter than base. Highest-leverage single change, and the one move every
school converges on independently: identifiers pop **without spending a
colour**.

```lua
["@punctuation"]      = "faint"   -- brackets, delimiters, special
["@tag.delimiter"]    = "faint"
["@operator"]         = "dim"
["@keyword"]          = "dim"     -- and every @keyword.* subcapture
["@type.builtin"]     = "dim"
["@variable.builtin"] = "dim"
["@constant.builtin"] = "dim"
["@module"]           = "dim"
```

Builtins are dimmed on the grounds that you never *look* for `string`, `int`,
`nil` or `err` — you already know they are there.

### Step 3 — `presets.foreign` (current)

Adds the "not code" tier — comments and literals are foreign grammars embedded
in the host language.

```lua
["@comment"]       = "strong"  -- loud, not dimmed
["@string"]        = "muted"
["@string.escape"] = "strong"  -- the one part of a string that is code
["@number"]        = "muted"
["@boolean"]       = "muted"
["@character"]     = "muted"
```

Two deliberate choices to re-examine while living with this:

- **Comments are loud, not dimmed**, following tonsky ("good comments ADD to
  the code… they are important"). This is the contested one — nearly every
  mainstream theme does the opposite. If your Go doc comments are mostly
  boilerplate `// Foo does foo.` restatements, this will feel wrong fast; flip
  `@comment` to `dim` and see which you prefer.
- **Literals are muted, not bright.** tonsky brightens them (they are anchors
  logic starts from); here they are pushed *below* base instead, so that base
  stays reserved for identifiers. If you find yourself hunting for string
  constants, try `"strong"` instead.

Note the resulting ramp is no longer monotone by "importance": comments sit
above identifiers, strings below. That is intentional — the axis is attention,
not semantic weight.

### Step 4 — `presets.attention` (next)

Adds hank.bond's tiers: definitions bold (`@function`, `@type.definition`,
`@constructor`) so you can scan "what does this file create?", and control-flow
exits strong (`@keyword.return`, `@keyword.exception`, `@keyword.coroutine`).

### Step 5 — dynamic layer

Put *identity* and *flow* information on an on-demand layer instead of the
static theme — LSP `document_highlight` on `CursorHold`, `MatchParen`,
cursor-scoped bracket highlighting. This is Wayne's overlay idea, and it is
what lets the static theme stay near-blank.

## Language-specific decisions still open

**Go — `return` may be a trap.** `if err != nil { return err }` is everywhere;
under step 4 every error branch lights up. Either exactly right (error paths
*are* the boundaries) or unbearable noise. Test on a handler-heavy file before
committing. `go` and `defer` (`@keyword.coroutine`) are safer — genuine control
flow discontinuities, and rare.

**TypeScript — types are the one defensible extra tier.** Sparse, deliberate,
in predictable positions, and they carry what Go carries structurally. The
Alabaster ports link `@type` to plain foreground; that is probably wrong for TS:

```lua
rules = vim.tbl_extend("force", highlight.presets.foreign, { ["@type"] = "strong" })
```

**JSX** is a separate call — `@tag` / `@tag.attribute` is arguably a foreign
grammar embedded in the host, which is the same argument that earns strings
their treatment.

## Customising

Presets are just tables of `capture -> tier`, so mix freely:

```lua
local highlight = require("user.highlight")
highlight.setup({
  rules = vim.tbl_extend("force", highlight.presets.scaffolding, {
    ["@comment"] = "strong",
    ["@type"]    = "muted",
  }),
  -- tiers = { dim = { blend = 0.5 } },  -- widen/narrow the ramp
})
```

Going much wider than the current ramp is where grayscale starts reading as
washed out rather than layered.

## Log

Append findings here as you move through the steps.

- **step 1 (blank), started.** _(fill in: what you missed, what felt better)_
- **steps 2+3 (`foreign`) applied** without a full evaluation period on blank,
  at request. If something feels off, the useful diagnostic is to drop back to
  `presets.blank` or `presets.scaffolding` for a day rather than tweaking tiers.
- **fix while applying step 2:** rule lookup now inherits up the capture
  hierarchy. Previously `@keyword` was dim but `@keyword.return`,
  `@keyword.coroutine` and `@keyword.conditional.ternary` had no rule of their
  own, so they rendered at base — *brighter* than surrounding keywords. Worth
  knowing if you add rules by hand: broad rules now cover whole families.
