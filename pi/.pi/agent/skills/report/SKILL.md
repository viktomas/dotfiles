---
name: report
description: Generate a standalone HTML report from a markdown file with d2 diagrams, SVGs, and syntax-highlighted code blocks. ALWAYS use when the user asks for or mentions a report. Use this skill for visual explanation.
---

# Task report

A report is a **snapshot of an understanding at a point in time** — an investigation
write-up with diagrams, for a human to read. Write it as markdown, render it to HTML with
`mdreport`, and freeze the markdown into the task's memory with `tm artifact` so a later
session can find it.

Write the markdown wherever the work is happening (the workspace, a scratch dir). There is
no reserved report path any more: `tm` holds the copy that outlives the session.

## Rendering

Always render the report after you write it!

```bash
mdreport report.md
```

Output defaults to `<filename.md without md suffix>.html` in the system temp folder and opens in the
browser. The generated HTML is for the human user only — NEVER read it, NEVER touch it.
An invalid `d2` or `svg` block aborts with exit 1, naming the block type and line. 

## Freezing the report into task memory

In a session with a `tm` task, freeze the markdown once it is written and rendered:

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
and only the live one shows up in the default views — which is what the hand-written
"the older report is outdated, don't read it" notes used to do by hand.

## Format

Standard GFM markdown, plus fenced blocks by info string:

- **d2** — compiled to inline SVG (https://d2lang.com).
- **svg** — inlined as-is, validated for an `<svg>` root. The page respects OS
  light/dark theme, so SVGs must not assume a white background.
- **diff** — a unified diff, rendered client-side by diff2html as a colored
  side-by-side diff with word-level highlighting. Use it whenever you show code
  changes; write a normal unified diff (`--- a/file`, `+++ b/file`, `@@ ... @@`).
- **GitHub alert callouts** — blockquotes starting with `> [!NOTE]`, `> [!TIP]`,
  `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` render as colored boxes
  with an icon; use them to flag severity/importance. Append `+`/`-` to the type
  (`> [!TIP]+` / `> [!CAUTION]-`) for a collapsible box, open/closed by default.
- **anything else** — a language name, syntax-highlighted client-side.

Raw HTML passes through, so `<details>`/`<summary>` collapsible sections work.
Leave a blank line after `<summary>` so its content is parsed as markdown.
Callouts and diffs render correctly inside `<details>` too.

````md
# Example report

Prose outside fences: headings, lists, **bold**, `inline code`, [links](https://example.com).

<details>
<summary>Extra details</summary>

Hidden **markdown**, code blocks, and d2 diagrams all work here.

</details>

```d2
client -> api: request
api -> db: query
db -> api: rows
api -> client: response
```

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 40">
  <rect x="2" y="2" width="116" height="36" rx="6" fill="none" stroke="currentColor"/>
  <text x="60" y="24" text-anchor="middle" font-family="sans-serif" fill="currentColor">custom mark</text>
</svg>
```

```js
console.log('hello world');
```

> [!WARNING]
> Callouts flag severity without any HTML or custom syntax.

```diff
--- a/main.go
+++ b/main.go
@@ -1,3 +1,3 @@
 func main() {
-	fmt.Println("hi")
+	fmt.Println("hello")
 }
```
````

## If `mdreport` binary is missing

Build first if the binary is missing:

```bash
make -C /Users/tomas/.pi/agent/skills/report/scripts install
```

