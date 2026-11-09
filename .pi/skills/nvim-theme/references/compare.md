# Comparing theme options with `compare.py`

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

