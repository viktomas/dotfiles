#import "lib.typ": *

// Kinesis Advantage 360 + kanata.
// Physical layout: the board's own key positions (outer 2-column blocks, five
// finger columns, inner 3-key column, rotated 6-key thumb clusters).
// Legends: ../kanata/.config/kanata/kanata.kbd + ../kanata/README.md.

#let mod = accent // home row mods
#let lay = accent2 // symbol layer triggers / overrides

#show: body => sheet(
  "Kinesis Advantage 360 · kanata",
  subtitle: [above: symbol layer · middle: tap · below: hold],
  body,
)

// ── Geometry ───────────────────────────────────────────────────
// Uniform 1u pitch everywhere. Seven columns per half; the two outer columns
// sit 0.26u lower than the five finger columns. The halves are exact mirrors
// of each other about `axis`, thumb clusters included.
#let o = 0.26 // outer block drop
#let span = 16.4 // x of the last column; the halves mirror about span/2
#let m(x) = span - x // mirror an x coordinate (same 1u key width both sides)

// Thumb cluster: a plain 3-column grid, tilted 15° as a whole (verified by
// rotating the screenshot by -15°, at which point every key is axis-aligned).
// Local coordinates below are relative to the cluster pivot; the right
// cluster is the same grid with x and the angle negated.
#let tilt = 15deg
#let pivot-x = 5.18
#let pivot-y = 5.2

#let diagram = board(w: 17.4, h: 7.8, y0: 0)[
  // ── Left outer block ─────────────────────────────────────────
  #cap(0, 0 + o, "=")
  #cap(0, 1 + o, "tab", size: 9pt)
  #cap(0, 2 + o, "esc", size: 9pt)
  #cap(0, 3 + o, "shift", size: 8.5pt)
  #cap(0, 4 + o, "cmd", size: 9pt)

  #cap(1, 0 + o, "1")
  #cap(1, 1 + o, "q", top: "!")
  #cap(1, 2 + o, "a", top: "#")
  #cap(1, 3 + o, "z")
  #cap(1, 4 + o, "`")

  // ── Left finger columns ──────────────────────────────────────
  #cap(2, 0, "2")
  #cap(2, 1, "w", top: "@")
  #cap(2, 2, "s", top: "_", sub: "alt", color: mod)
  #cap(2, 3, "x")
  #cap(2, 4, "spc", size: 9pt)

  #cap(3, 0, "3")
  #cap(3, 1, "e", top: "[")
  #cap(3, 2, "d", top: "(", sub: "cmd", color: mod)
  #cap(3, 3, "c", top: "{")
  #cap(3, 4, "←")

  #cap(4, 0, "4")
  #cap(4, 1, "r", top: "]")
  #cap(4, 2, "f", top: ")", sub: "ctrl", color: mod)
  #cap(4, 3, "v", top: "}")
  #cap(4, 4, "→")

  #cap(5, 0, "5")
  #cap(5, 1, "t", top: "|")
  #cap(5, 2, "g", top: "`", sub: "sym", color: lay)
  #cap(5, 3, "b", top: "~")

  // Inner column — Adv360 keys, kanata never sees the layer taps
  #cap(6, 0, "T1", sub: "board", size: 9pt)
  #cap(6, 1, "1", sub: "board", size: 9pt)
  #cap(6, 2, "2", sub: "board", size: 9pt)

  // ── Right inner column ───────────────────────────────────────
  #cap(m(6), 0, "M3", sub: "board", size: 9pt)
  #cap(m(6), 1, "3", sub: "board", size: 9pt)
  #cap(m(6), 2, "4", sub: "board", size: 9pt)

  // ── Right finger columns ─────────────────────────────────────
  #cap(m(5), 0, "6")
  #cap(m(5), 1, "y")
  #cap(m(5), 2, "h", top: "-", sub: "sym", color: lay)
  #cap(m(5), 3, "n")

  #cap(m(4), 0, "7")
  #cap(m(4), 1, "u", top: "7")
  #cap(m(4), 2, "j", top: "4", sub: "ctrl", color: mod)
  #cap(m(4), 3, "m", top: "1")
  #cap(m(4), 4, "↑")

  #cap(m(3), 0, "8")
  #cap(m(3), 1, "i", top: "8")
  #cap(m(3), 2, "k", top: "5", sub: "cmd", color: mod)
  #cap(m(3), 3, ",", top: "2")
  #cap(m(3), 4, "↓")

  #cap(m(2), 0, "9")
  #cap(m(2), 1, "o", top: "9")
  #cap(m(2), 2, "l", top: "6", sub: "alt", color: mod)
  #cap(m(2), 3, ".", top: "3")
  #cap(m(2), 4, "[")

  // ── Right outer block ────────────────────────────────────────
  #cap(m(1), 0 + o, "0")
  #cap(m(1), 1 + o, "p", top: "*")
  #cap(m(1), 2 + o, ";", top: "+")
  #cap(m(1), 3 + o, "/", top: "=")
  #cap(m(1), 4 + o, "]")

  #cap(m(0), 0 + o, "-")
  #cap(m(0), 1 + o, "\\")
  #cap(m(0), 2 + o, "'")
  #cap(m(0), 3 + o, "shift", sub: "tap ⌃Y", color: lay, size: 8.5pt)
  #cap(m(0), 4 + o, "M2", sub: "board", size: 9pt)

  // ── Left thumb cluster ───────────────────────────────────────
  // col 0: bspc (2u) · col 1: ctrl over esc (2u) · col 2: alt, home, cmd
  #cluster(pivot-x, pivot-y, tilt)[
    #cap(0, 0, "bspc", h: 2, size: 9pt)
    #cap(1, 0, "esc", h: 2, size: 9pt)
    #cap(1, -1, "ctrl", size: 8.5pt)
    #cap(2, -1, "alt", size: 8.5pt)
    #cap(2, 0, "home", size: 8.5pt)
    #cap(2, 1, "cmd", size: 8.5pt)
  ]

  // ── Right thumb cluster — same grid, mirrored ──────────────────────
  #cluster(m(pivot-x), pivot-y, -tilt)[
    #cap(0, 0, "space", top: "0", sub: "+j/k = tab", h: 2, color: lay, size: 9pt)
    #cap(-1, 0, "ret", h: 2, size: 9pt)
    #cap(-1, -1, "ctrl", size: 8.5pt)
    #cap(-2, -1, "L1", sub: "board", size: 8.5pt)
    #cap(-2, 0, "L2", sub: "board", size: 8.5pt)
    #cap(-2, 1, "cmd", size: 8.5pt)
  ]
]

#block(
  radius: 3pt,
  stroke: 0.5pt + hair,
  clip: true,
  inset: 0pt,
)[
  #diagram
  #block(width: 100%, inset: (x: 6pt, y: 4pt))[
    #stack(
      dir: ltr,
      spacing: 14pt,
      swatch(mod, "home row mod — hold for ⌥ ⌘ ⌃"),
      swatch(lay, "layer / override"),
      text(size: 8pt, fill: accent2)[rust legend = symbol layer output],
      text(size: 8pt, fill: muted)[grey legend = what holding does],
    )
  ]
]

#v(6pt)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 7pt,

  panel(
    "Symbol layer — hold g or h",
    rows(
      ("g", [hold, then #key("h") → #key("-") · cross-trigger]),
      ("h", [hold, then #key("g") → #key("`") · cross-trigger]),
      ("spc", [#key("0") — the whole right hand is a numpad]),
      ("⇧ 4567", [`$%^&` — not on the layer, use shift]),
    ),
    color: lay,
  ),

  panel(
    "Media row (F1–F12, no physical row)",
    grid(
      columns: (1fr, 1fr),
      gutter: 4pt,
      rows(
        ("F1", "brightness -"),
        ("F2", "brightness +"),
        ("F5", "keyboard light -"),
        ("F6", "keyboard light +"),
      ),
      rows(
        ("F7", "previous track"),
        ("F8", "play / pause"),
        ("F9", "next track"),
        ("F10-F12", "mute, vol -, vol +"),
      ),
    ),
    color: lay,
  ),

  stack(
    spacing: 6pt,
    panel(
      "Board keys — Adv360 firmware, not kanata",
      rows(
        ("T1 M2 M3", "board layer / macro keys"),
        ("L1 L2", "thumb layer-access keys"),
        ("1 2 3 4", "inner columns, board-side taps"),
      ),
      color: lay,
    ),
    panel(
      "Ops",
      [
        #set text(font: "JetBrainsMono NFM", size: 7.5pt)
        #stack(
          spacing: 3pt,
          [launchctl kickstart -k system/com.kanata.daemon],
          [tail -f /var/log/kanata.log],
          [lctl+spc+esc #h(4pt) #text(font: "Helvetica Neue", fill: muted)[panic: release all keys]],
        )
      ],
      color: lay,
    ),
  ),
)
