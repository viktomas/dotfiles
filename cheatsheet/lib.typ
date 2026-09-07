// Shared visual primitives for all cheatsheets.
// Keep every sheet looking the same: same palette, same panel, same key caps.

// ── Palette ────────────────────────────────────────────────────
// Two accents max, greys carry the structure.
#let ink = rgb("#22252b")
#let accent = rgb("#2f5d8c") // primary: panel titles, modifiers
#let accent2 = rgb("#9c5321") // secondary: layer keys, warnings
#let hair = rgb("#c9ccd1") // hairlines, borders
#let zebra = rgb("#f4f5f7") // alternating row fill
#let soft = rgb("#e8eaee") // key cap fill
#let muted = rgb("#6b7280") // de-emphasised text

// ── Page setup ─────────────────────────────────────────────────
// One page. If it spills, cut content — not the font size.
#let sheet(title, subtitle: none, body) = {
  set page(
    paper: "a4",
    flipped: true,
    margin: 10mm,
    footer: context align(right, text(size: 7pt, fill: muted)[
      #title #h(4pt) · #h(4pt) #datetime.today().display("[year]-[month]-[day]")
      #h(4pt) · #h(4pt) #counter(page).display()
    ]),
  )
  set text(font: "Helvetica Neue", size: 9pt, fill: ink)
  set par(leading: 0.5em)

  block(below: 8pt)[
    #text(size: 15pt, weight: "bold", title)
    #if subtitle != none {
      h(6pt)
      text(size: 9pt, fill: muted, subtitle)
    }
  ]
  body
}

// ── Panel ──────────────────────────────────────────────────────
// The only structural element: a bordered box with a filled title strip.
#let panel(title, body, color: accent) = block(
  width: 100%,
  radius: 3pt,
  stroke: 0.5pt + hair,
  clip: true,
  breakable: false,
  inset: 0pt,
)[
  #block(width: 100%, fill: color, inset: (x: 5pt, y: 3pt))[
    #text(size: 8pt, weight: "bold", tracking: 0.6pt, fill: white, upper(title))
  ]
  #block(width: 100%, inset: (x: 5pt, y: 4pt))[#body]
]

// ── Key cap ────────────────────────────────────────────────────
// One keystroke. `color` tints the cap (modifiers vs. layer keys).
#let key(label, color: none, width: auto) = box(
  fill: if color == none { soft } else { color.lighten(80%) },
  stroke: 0.4pt + if color == none { hair } else { color.lighten(40%) },
  radius: 2pt,
  inset: (x: 3pt, y: 1.5pt),
  width: width,
  baseline: 1.5pt,
)[#align(center, text(
  font: "JetBrainsMono NFM",
  size: 7.5pt,
  weight: "medium",
  fill: if color == none { ink } else { color.darken(15%) },
  label,
))]

// A whitespace-separated sequence of keystrokes: `keys("d left")`.
#let keys(spec, color: none) = {
  if type(spec) != str { return spec }
  spec.split(" ").map(k => key(k, color: color)).join(h(2pt))
}

// ── Rows ───────────────────────────────────────────────────────
// Two-column key/description table. Left column is key caps.
#let rows(..pairs) = table(
  columns: (auto, 1fr),
  inset: (x: 3pt, y: 2.6pt),
  align: (left + horizon, left + horizon),
  stroke: (x, y) => (top: if y == 0 { none } else { 0.3pt + hair }),
  fill: (x, y) => if calc.odd(y) { zebra },
  ..pairs
    .pos()
    .map(p => (keys(p.at(0)), text(size: 8pt, p.at(1))))
    .flatten()
)

// ── Keyboard ───────────────────────────────────────────────────
// Split, column-staggered board drawn on a coordinate grid: one `unit` is a
// key pitch, x grows right, y grows down, both can be fractional so columns
// can be staggered and the two halves separated.

#let unit = 42pt // horizontal pitch
#let unit-y = 42pt // vertical pitch
#let cap-gap = 3pt

// A physical key with up to three legends:
//   top  — what the other layer produces (symbol layer)
//   main — the base legend
//   sub  — what holding it does
#let cap(
  x,
  y,
  main,
  top: none,
  sub: none,
  w: 1,
  h: 1,
  color: none,
  size: 11pt,
  angle: 0deg,
) = place(
  dx: x * unit,
  dy: y * unit-y,
  rotate(angle, origin: center + horizon, box(
    fill: if color == none { white } else { color.lighten(88%) },
    stroke: 0.5pt + if color == none { hair } else { color.lighten(35%) },
    radius: 5pt,
    width: w * unit - cap-gap,
    height: h * unit-y - cap-gap,
    inset: (x: 1pt, y: 2pt),
  )[
    #set align(center + horizon)
    #set text(hyphenate: false)
    #stack(
      spacing: 2pt,
      if top != none {
        text(font: "JetBrainsMono NFM", size: 8.5pt, fill: accent2, top)
      },
      text(
        font: "JetBrainsMono NFM",
        size: size,
        weight: "medium",
        fill: if color == none { ink } else { color.darken(25%) },
        main,
      ),
      if sub != none {
        text(size: 7pt, fill: if color == none { muted } else { color.darken(5%) }, sub)
      },
    )
  ]),
)

// A rotated group of caps — the thumb clusters are a plain grid, tilted as a
// whole. Caps inside use coordinates local to (x, y), which is also the pivot.
#let cluster(x, y, angle, body) = place(
  dx: x * unit,
  dy: y * unit-y,
  rotate(angle, origin: top + left, box(body)),
)

// A board: fixed-size canvas the `cap()`s are placed into. Coordinates are in
// units; `w`/`h` are the extent of the layout, `x0`/`y0` its origin.
#let board(w: 15.5, h: 6.8, y0: -1.3, body) = block(
  width: 100%,
  height: h * unit-y,
  fill: rgb("#f3f4f6"),
  radius: 3pt,
  inset: 0pt,
)[
  // The layout is `w` units wide; centre it in whatever width we get.
  #place(
    center + top,
    box(width: w * unit, height: h * unit-y)[
      #place(dx: 0pt, dy: -y0 * unit-y, box(body))
    ],
  )
]


// Small inline legend swatch, for explaining the colour coding.
#let swatch(color, label) = box(baseline: 1pt)[
  #box(
    fill: color.lighten(85%),
    stroke: 0.4pt + color.lighten(30%),
    radius: 1.5pt,
    width: 8pt,
    height: 8pt,
  )
  #h(1pt) #text(size: 7.5pt, fill: muted, label)
]
