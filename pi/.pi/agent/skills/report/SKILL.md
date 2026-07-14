---
name: report
description: Generate a standalone HTML report from a markdown file with d2 diagrams, SVGs, and syntax-highlighted code blocks. ALWAYS use when the user asks for or mentions a report. Use this skill for visual explanation.
---

# Task report

Each task has a default report file location which might or might not contain a file, run `task report` to get the file location.

Write the report as markdown, then render it to HTML with `mdreport`.

You can write an extra report to a different location if asked, but default to the `task report` file.

## Rendering

Always render the report after you write it!

```bash
mdreport report.md
mdreport $(task report)
```

Output defaults to `<filename.md without md suffix>.html` in the system temp folder and opens in the
browser. The generated HTML is for the human user only — NEVER read it, NEVER touch it.
An invalid `d2` or `svg` block aborts with exit 1, naming the block type and line. 

## Format

Standard GFM markdown, plus fenced blocks by info string:

- **d2** — compiled to inline SVG (https://d2lang.com).
- **svg** — inlined as-is, validated for an `<svg>` root. The page respects OS
  light/dark theme, so SVGs must not assume a white background.
- **anything else** — a language name, syntax-highlighted client-side.

Raw HTML passes through, so `<details>`/`<summary>` collapsible sections work.
Leave a blank line after `<summary>` so its content is parsed as markdown.

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
````

## If `mdreport` binary is missing

Build first if the binary is missing:

```bash
make -C /Users/tomas/.pi/agent/skills/report/scripts install
```

