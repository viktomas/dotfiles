---
name: report
description: Write an investigation report with diagrams rendered inline in the terminal (d2, svg). ALWAYS use when the user asks for or mentions a report. Use this skill for visual explanation.
---

# Task report

A report is a **snapshot of an understanding at a point in time** — an investigation
write-up with diagrams, for a human to read.

The report lives in two places:

1. **The transcript** — write the prose directly in your reply as markdown, and render each
   diagram inline so the user reads it without leaving the terminal.
2. **A markdown file** — the same content, frozen into the task's memory with
   `tm artifact` so a later session can find it. Write the file wherever the work is
   happening (the workspace, a scratch dir); `tm` holds the copy that outlives the session.

## Diagrams

Just write a fenced ```d2 or ```svg block in your reply. The `diagram` extension renders
every complete block to an image below the message (Kitty graphics protocol) and replaces
the raw source with a `◈ diagram N` marker, so the prose stays readable.

If a block fails to compile, its source stays visible and you get a message with the
compiler error — fix it and repost the corrected block.

You never see the rendered image yourself, so keep diagrams small enough to be obviously
correct. To eyeball one, render it manually and `read` the PNG:

```bash
diagram flow.d2          # prints the PNG path; -w max width px, -H max height
echo 'a -> b' | diagram -t d2 -
```

- **d2** — https://d2lang.com. The image is capped at ~45 rows tall and the transcript
  width, and the terminal cannot zoom, so the diagram's own size decides how big its text
  ends up. Default layout is top-down, which burns the height budget fastest: add
  `direction: right` for flows, and split anything past ~8 nodes into several diagrams.
- **svg** — must have an `<svg>` root and an explicit `viewBox`. Rendered on a white
  background, so use dark strokes/fills (`#111`, `#1a56db`), never `currentColor`.

The markdown file keeps the fenced source, not the PNG, so a later session re-renders it
by quoting the block back or running `diagram` on it.

## Everything else is plain markdown

Prose, headings, lists, tables, `inline code`, links, and fenced code blocks all render in
the transcript. Use fenced ```diff blocks with a normal unified diff (`--- a/file`,
`+++ b/file`, `@@ ... @@`) whenever you show code changes.

In the markdown file, keep each diagram as a fenced ```d2 / ```svg block at the place where
it belongs.

## Freezing the report into task memory

In a session with a `tm` task, freeze the markdown once it is written:

```bash
tm artifact ./report.md --note "Turn-cancellation: root cause + fix options"
```

`tm` copies the file into the task's `artifacts/` dir and prints the absolute path of the
frozen copy. `tm resume`/`tm show` then list it for every later session, so nobody has to
remember where the report went.

**Never edit a frozen artifact, and never keep a report as a living document.** A report
that is edited in place drifts from reality and nobody can tell whether it still describes
the current state. When your understanding changes, write a new report and supersede the
old one:

```bash
tm artifact ./report-v2.md --note "Revised after the debug-log capture" --supersedes a1
```

The superseded snapshot stays in the log, honest about what was true when it was written,
and only the live one shows up in the default views.

## Machinery

- `~/.pi/agent/extensions/diagram.ts` — renders ```d2 / ```svg blocks in assistant messages,
  caches PNGs in `~/.cache/pi/diagrams/`, reports failures back to the agent.
- `~/.pi/agent/skills/report/scripts/diagram` — bash helper (`d2` + `rsvg-convert`), also
  symlinked as `~/bin/diagram`. If it is missing:
  `ln -sf ~/.pi/agent/skills/report/scripts/diagram ~/bin/diagram && brew install d2 librsvg`
