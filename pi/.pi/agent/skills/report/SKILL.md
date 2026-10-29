---
name: report
description: Generate a standalone HTML report from a markdown file with d2 diagrams, SVGs, and syntax-highlighted code blocks. ALWAYS use when the user asks for or mentions a report. Use this skill for visual explanation.
---

# Task report

A report is a **snapshot of an understanding at a point in time** — an investigation
write-up with diagrams, for a human to read. Write it as markdown, render it to HTML with
`mdreport`, and, in a task session, keep the markdown next to the task's state file so a
later session can find it.

Outside a task, write the markdown wherever the work is happening (the workspace, a
scratch dir).

## Rendering

Always render the report after you write it!

```bash
mdreport report.md
```

Output defaults to `<filename.md without md suffix>.html` in the system temp folder and opens in the
browser. The generated HTML is for the human user only — NEVER read it, NEVER touch it.
An invalid `d2` or `svg` block aborts with exit 1, naming the block type and line.

**Never pass an explicit output path.** The temp folder is the point: the HTML is an ephemeral,
browser-only view that dies with the temp dir, while the `.md` is the durable artifact a later
session can find and re-render. Writing the HTML into the workspace (next to the `.md`, into the
task state dir, anywhere tracked) doubles the artifact and goes stale the moment the markdown
moves. Only render somewhere persistent when the user explicitly asks for a keepable HTML file. 

## Keeping the report with the task

When `$TASK_ID` is set, write the report into the state directory, named after the task,
and list it in the state file (the `task-management` skill) with a one-line note:

```bash
r="$(dirname "$(task state)")/$TASK_ID-$(date +%Y%m%d)-turn-cancellation.md"
```

**Never edit a written report, and never keep a report as a living document.** A report
that is edited in place drifts from reality and nobody can tell whether it still describes
the current state. When your understanding changes, write a new report file and, in the
state file, point at the new one and mark the old one as superseded (and why).

## As a book (optional)

The HTML is the default. Only when I ask for an epub / a book / something for the
reader, also build one from the **same markdown** with the `epub` skill — never a
separate copy of the text:

```bash
~/.agents/skills/epub/scripts/build_epub.py "$r" --shots /tmp/shots-$TASK_ID
```

The book lands beside the `.md` (`${r%.md}.epub`); list it on the report's line in the
state file. Write every report so it *could* become a book; it costs nothing in the
browser:

- Don't let colour alone carry meaning in d2/svg — use a label, dash pattern or border.
  The book is grayscale.
- Keep tables to ~4 short columns; put long text in prose or a list.
- Link to files with an `https://` URL (GitLab/Forgejo blob) when it should stay
  clickable; a relative link like `./repro.sh` becomes plain text in the book.
- Prefer one tall d2 diagram (`direction: down`) over one long row of boxes.

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

## Writing it (avoid LLM tells)

**Every sentence must contain something that could be wrong:** a date, a count, a state
(merged/open/closed), a named alternative. Cut anything nobody could disagree with.

Banned:

- Antithesis: `not X, but Y`, `isn't just`, `not merely`.
- Participial significance tails (`, demonstrating…`, `, ensuring…`): delete, state the fact.
- Excess vocabulary: delve, showcase, underscore, pivotal, crucial, robust, seamless,
  leverage, holistic, comprehensive, testament, landscape, nuanced, load-bearing.
- Copula avoidance: `serves as`, `functions as`, `represents a` → `is`.
- Significance inflation (`transformative`, `game-changing`); rule-of-three on every list.
- Punchy fragments after a full sentence (`Not a detail. A design decision.`); em-dash pile-ups.

Instead: numbers over adjectives (`72s → 13s`), name the real alternative that existed, one
claim per sentence, dates from the API/source (not `recently`/`now`), tables for state, not prose.
Diagrams and tables carry the structure, so prose stays short; never restate a diagram in prose.

Before rendering, grep the finished file, read every hit, and fix by hand:

```bash
grep -nEi "not (just|only|merely|simply)|isn't just|it's not" "$r"
grep -nEi ", (ensuring|highlighting|underscoring|showcasing|demonstrating|reflecting|emphasizing|enabling|allowing|driving|fostering|proving)" "$r"
grep -nEiw "delve|showcase|underscore|pivotal|crucial|intricate|robust|seamless|leverage|holistic|comprehensive|testament|landscape|realm|nuanced|multifaceted|invaluable|load-bearing|significant" "$r"
grep -nEi "serves as|functions as|stands as|represents a|marks a|emerged as" "$r"
grep -nEi "transformative|game.?chang|paradigm|recently|currently" "$r"
```

Fix hollow constructions only; leave dashes and triples that carry a fact.

## If `mdreport` binary is missing

Build first if the binary is missing:

```bash
make -C /Users/tomas/.pi/agent/skills/report/scripts install
```

