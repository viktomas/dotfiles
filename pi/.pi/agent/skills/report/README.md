# Report skill — design notes

Why the report skill looks the way it does, and which of its rough edges are deliberate.
`SKILL.md` tells the agent what to do; this file explains the constraints behind those
instructions, so the next change doesn't re-litigate them from scratch.

## Pieces

| Piece | Path | Role |
|---|---|---|
| Skill | `SKILL.md` | Instructions the agent loads when a report is requested |
| Helper | `scripts/diagram` (→ `~/bin/diagram`) | `d2`/`svg` source → PNG, via `d2` + `rsvg-convert` |
| Extension | `~/.pi/agent/extensions/diagram.ts` | Renders fenced blocks from assistant messages into the transcript |
| Cache | `~/.cache/pi/diagrams/<sha1>-<w>x<h>.png` | Content-addressed, so re-rendering is free |

The report itself is two artefacts: the transcript (what the human reads now) and a
markdown file frozen with `tm artifact` (what a later session reads).

## History: why not HTML any more

The previous version generated a standalone HTML page (a ~1k-line Go tool: d2 → inline SVG,
diff2html, highlight.js, zoom and annotation JS) and opened a browser. That bought
scrollable, zoomable, richly formatted output — at the cost of leaving the terminal for
every diagram.

Once zellij gained Kitty graphics protocol support, the diagrams — the only part that
genuinely needed a browser — could be drawn in the transcript, so the HTML pipeline was
deleted. What was lost with it: side-by-side word-level diffs, collapsible `<details>`
sections, GitHub-style callouts, and zoom. If any of those start to hurt, the honest fix is
to bring back a render target, not to bolt them onto the terminal.

## Limitation 1: diagrams land *below* the message, never inline

A pi transcript is a flat list of components. An assistant message is **one** component
containing rendered markdown; there is no way to interleave an image component into the
middle of it. Images can only enter the transcript as separate components:

- a `read` tool result (also costs image tokens, and is framed as a tool call), or
- a custom entry appended via `pi.appendEntry()` + `registerEntryRenderer()` (TUI-only,
  no LLM cost) — what the extension uses.

So diagrams appear after the message that declared them. The extension compensates by
replacing each fenced block with a `◈ diagram N (d2)` marker, so the prose still shows
*where* each diagram belongs and the numbering matches the images below.

**Design consequence for the skill:** write prose that survives the separation. Refer to
"diagram 2" rather than "the diagram below", and don't put a diagram's punchline in the
diagram alone.

There is a sharp edge here worth remembering: `addCustomEntryToChat` in pi's interactive
mode *splices* new entries above the streaming component while a message is still
streaming. Appending from inside a `message_end` handler therefore puts the images **above**
the message. The extension defers past the emit (`setTimeout(…, 0)`) so the message settles
first.

## Limitation 2: the terminal cannot zoom

An image occupies a fixed cell box (currently ≤160 columns × 45 rows, and the width is
clamped to the transcript width). There is no zoom, no pan, no "open larger". The
diagram's own complexity therefore decides the final text size: more nodes in the same box
means smaller glyphs, and nothing downstream can rescue it.

Two things follow, and both are already in `SKILL.md`:

- Rasterise at 2× the on-screen box (cell size × `MAX_WIDTH/HEIGHT_CELLS`), so the terminal
  downscale stays crisp. Upscaling is free — the source is vector, so `scripts/diagram`
  deliberately has no zoom cap.
- **Keep diagrams small.** Prefer `direction: right` (the default top-down layout consumes
  the scarce height budget fastest) and split anything past ~8 nodes. This is the actual
  fix; resolution is not.

## Limitation 3: the agent is blind to its own diagrams

Custom entries never reach the model, which is the point — a report full of PNGs would
otherwise burn image tokens on every subsequent turn. The price is that the agent cannot
see whether a diagram is legible or whether labels overlap. Only *failures* come back, as a
custom message carrying the d2 compiler error, with two guards:

- a failed block keeps its source visible instead of showing a marker with no image;
- the same failing source never triggers a second turn, so a stubborn diagram can't loop.

If a diagram needs visual checking, the agent renders it manually and `read`s the PNG,
paying the image tokens knowingly. That is the escape hatch, not the default path.

## Limitation 4: the frozen artifact is text

`tm artifact` freezes the markdown, not the images. Diagrams survive as fenced source,
which a later session re-renders on demand — this is why the extension only hides the block
for display and never rewrites the message content. It also means a report read outside pi
(an editor, a git diff) shows d2 source rather than pictures. Acceptable: the source is
readable, and reports are snapshots, not living documents.

## Non-goals

- **No living reports.** A report is a snapshot; new understanding means a new report with
  `--supersedes`, never an edit of a frozen artifact.
- **No general markdown renderer.** The extension renders `d2` and `svg` only. Everything
  else stays plain markdown that pi already renders (```mermaid is handled by pi itself as
  Unicode box art).
- **No user-message rendering.** The transformer skips user messages; markers with no
  images behind them would be worse than raw source.
