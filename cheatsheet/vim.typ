#import "lib.typ": *

// Things that don't stick yet. Add a panel when you catch yourself looking
// something up twice.

#show: body => sheet(
  "Neovim",
  subtitle: [mini.surround — grammar: #key("action") + #key("target")],
  body,
)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 7pt,

  // ── Column 1 ─────────────────────────────────────────────────
  stack(
    spacing: 6pt,

    panel(
      "Actions",
      rows(
        ("sa", [add — takes a *textobject*, then a target: `saiw)`]),
        ("sa", "in visual mode: surrounds the selection"),
        ("sd", "delete surrounding"),
        ("sr", "replace surrounding (old target, then new)"),
        ("sf", "find right edge"),
        ("sF", "find left edge"),
        ("sh", "highlight surrounding briefly"),
        (".", "everything dot-repeats"),
      ),
    ),

    panel(
      "Targets",
      rows(
        (") ] } >", "the bracket, tight"),
        ("( [ { <", "the bracket, padded with spaces"),
        ("b", "any bracket: ( [ {"),
        ("q", "any quote: ' \" `"),
        ("t", "tag — prompts for the name on replace/add"),
        ("f", "function call — prompts for the name"),
        ("?", "prompt for left + right yourself"),
        ("other", [the character itself: `_` `*` `|`]),
      ),
      color: accent2,
    ),
  ),

  // ── Column 2 ─────────────────────────────────────────────────
  stack(
    spacing: 6pt,

    panel(
      "Examples",
      table(
        columns: (auto, 1fr),
        inset: (x: 3pt, y: 2.6pt),
        align: (left + horizon, left + horizon),
        stroke: (x, y) => (top: if y == 0 { none } else { 0.3pt + hair }),
        fill: (x, y) => if calc.odd(y) { zebra },
        ..(
          ("saiw)", [`word` → `(word)`]),
          ("saiw(", [`word` → `( word )`]),
          ("sa$\"", [to end of line, in double quotes]),
          ("sdq", [`"word"` → `word`]),
          ("sr'\"", [`'word'` → `"word"`]),
          ("sr)t" + "div⏎", [`(x)` → `<div>x</div>`]),
          ("sdf", [`fn(x)` → `x`]),
          ("srf" + "log⏎", [`fn(x)` → `log(x)`]),
          ("saiw?" + "**⏎**⏎", [`word` → `**word**`]),
          ("sdt", [drop the surrounding tag]),
        )
          .map(p => (
            text(font: "JetBrainsMono NFM", size: 8pt, weight: "medium", p.at(0)),
            text(size: 8pt, p.at(1)),
          ))
          .flatten()
      ),
    ),

    panel(
      "Which one, when there are several",
      rows(
        ("2sd)", "count: the 2nd surrounding outwards"),
        ("sdn)", "next — the one after the cursor"),
        ("sdl)", "last — the one before the cursor"),
        ("2sfnt", "combine: 2nd next tag, find its right edge"),
        ("srln)", "prefix order is action, count, n/l, target"),
      ),
      color: accent2,
    ),
  ),

  // ── Column 3 ─────────────────────────────────────────────────
  stack(
    spacing: 6pt,

    panel(
      "Gotchas",
      rows(
        ("20", "n_lines: search gives up beyond 20 lines"),
        ("V sa", "linewise selection puts surroundings on own lines"),
        ("sa", "normal mode needs a textobject; visual does not"),
        ("f", [matches `name(...)`, incl. dots: `a.b(x)`]),
        ("t", [self-nested `<a><a></a></a>` won't match]),
      ),
    ),

    panel(
      "Also mine",
      rows(
        ("<leader>c", "GitPermalink — link to the line on GitLab"),
        ("<leader>", "space"),
      ),
      color: accent2,
    ),
  ),
)
