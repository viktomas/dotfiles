# Cheatsheets

Printable A4 reference sheets. Rendered with [typst](https://typst.app)
(already installed via homebrew). Not a stow package — nothing here is
symlinked, it's just source + generated PDFs.

## Build

    typst compile keyboard.typ        # one-off -> keyboard.pdf
    typst watch   vim.typ             # live reload while editing

    for f in *.typ; do [ "$f" = lib.typ ] || typst compile "$f"; done   # all

## Design

One file per sheet, plus a shared `lib.typ` with the visual primitives so all
sheets look the same.

Page: A4, `flipped: true` (landscape suits a keyboard diagram), ~10mm margins,
9-10pt body font. Aim for one page — if it spills, cut content, not the font size.

Layout: a `grid` of "panel" boxes (title bar + body), flowing in 2-3 columns.
Each panel is one topic; panels are the only structural element, so the sheet
stays scannable.

`lib.typ` exposes:

- `sheet(title, subtitle: none, body)` — page setup + heading; used via
  `#show: body => sheet(...)`.
- `panel(title, body, color: accent)` — bordered, rounded box with a filled
  title strip.
- `key(label)` / `keys("spc j")` — small rounded mono boxes for keystrokes;
  `keys` splits on spaces and passes content through untouched.
- `rows(..pairs)` — two-column key/description table with hairline separators
  and zebra fill. Each pair is `(left, right)`; a string on the left becomes
  `keys()`, content is used as-is.
- `board(w:, h:, y0:, body)` + `cap(x, y, main, top:, sub:, w:, h:, color:)` —
  physical key diagrams. `board` is a fixed-size canvas, `cap` places a keycap
  on a coordinate grid where one step is `unit` (x) / `unit-y` (y). Fractional
  coordinates give the column stagger and the gap between the two halves.
  Each cap carries up to three legends: `top` (other layer, rust), `main`
  (tap), `sub` (hold). `board` centres the layout in whatever width it gets.
- `cluster(x, y, angle, body)` — a group of caps tilted as a whole, for the
  thumb clusters. Caps inside use coordinates local to `(x, y)`, which is also
  the pivot, and may be negative.
- `swatch(color, label)` — inline legend chip.
- palette: `accent` (blue), `accent2` (rust), plus `ink` / `muted` / `hair` /
  `zebra` / `soft` greys.

## Sheets

### keyboard.typ

The Kinesis Advantage 360 with kanata on top. The diagram is the board's own
physical layout: seven columns per half at a uniform 1u pitch — two outer
columns dropped 0.26u, four finger columns, a 3-key inner column — plus the
6-key thumb clusters.

A thumb cluster is a plain 3-column grid tilted 15° as a whole: `bspc` (2u),
then `ctrl` over `esc` (2u), then `alt` / `home` / `cmd`. To re-derive the
angle, rotate the reference screenshot until the keys are axis-aligned
(`magick shot.png -crop ... -rotate -15`) and read the grid off the result.

The halves are exact mirrors: the right half is `m(x)` of the left, thumb
clusters included, so a left-hand coordinate change automatically moves its
right-hand twin. Only edit the left half's numbers.

All layers live on the same keycap: symbol-layer output above in rust, the tap
legend in the middle, the hold action below. Blue caps = home row mods, rust
caps = layer/override keys. Keys the Adv360 firmware handles on its own (`T1`,
`M2`, `M3`, `L1`, `L2`, inner-column digits) are marked `board` — kanata never
sees them.

Deliberately *not* on this sheet: how kanata resolves tap vs. hold, the
`defhands` split, and the timing parameters. That is design rationale, it lives
in `../kanata/README.md`. The sheet only answers "what does this key do".

When the kanata config changes, update both the diagram and the rule panels.

### vim.typ

Panels of `rows()`. Currently mini.surround only (actions, targets, examples,
`n`/`l` search suffixes, gotchas) — deliberately sparse; add panels as things
stop sticking.
