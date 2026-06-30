---
name: html-report
description: Generate standalone HTML reports with dark theme, Mermaid diagrams, and auto-open in browser. Use when asked to create a report, analysis document, or visual summary.
---

# HTML Report Skill

Generate self-contained HTML reports. Reports go in `/tmp/` (never pollute the project tree), and open in the browser when done.

## Workflow

1. Create a temp directory: `/tmp/<descriptive-name>/`
2. If using Mermaid diagrams, draft `.mmd` files and validate with the mermaid skill before embedding
3. Write `report.html` using the template in `resources/template.html` as a starting point
4. **Finalize**: `./tools/inject-annotations.sh /tmp/<descriptive-name>/report.html` — this is mandatory, every report must be finalized before opening
5. Open: `open /tmp/<descriptive-name>/report.html`

**Never skip step 4.** Never open a report without running the inject script first.

## Template

Read `resources/template.html` as a **starting point only**. It provides a base dark theme and common components, but you should adapt, extend, and add custom CSS as needed to best represent the specific content. Every report is different — add new component styles, tweak layouts, use CSS grid/flexbox creatively, add animations, whatever serves the information.

The template gives you:

- Dark theme (Tokyo Night palette) with CSS variables
- Responsive layout, table styling, code blocks
- Card components (`.card`, `.card.highlight`, `.card.warn`, `.card.success`)
- Callout boxes (`.callout-info`, `.callout-warn`)
- Tags/badges (`.tag-green`, `.tag-blue`, `.tag-orange`, `.tag-red`, `.tag-purple`)
- Table of contents structure
- Mermaid rendering setup
- Syntax highlighting via highlight.js (Tokyo Night Dark theme)

Don't limit yourself to what's in the template. Add custom styles, new component types, different layouts — whatever makes the report clear and visually effective for the content at hand.

## Mermaid Diagrams

Mermaid renders client-side via CDN. Embed diagrams directly in HTML:

```html
<div class="mermaid-wrapper">
<pre class="mermaid">
graph LR
    A[#quot;Step 1#quot;] --> B[#quot;Step 2#quot;]
    B --> C[#quot;Step 3#quot;]
</pre>
</div>
```

The template includes the Mermaid JS CDN and `mermaid.initialize()` at the bottom.

**Important**: The `<pre class="mermaid">` content is parsed as HTML first, then by Mermaid. This means:
- Raw `"` inside the `<pre>` will break the HTML — the browser sees it as closing an attribute
- Raw `#` is interpreted by Mermaid as the start of an entity (e.g., `#123;` becomes a character code)

You **must** use Mermaid's own entity escapes (`#quot;`, `#35;`, `#59;` — NOT
`&`-prefixed HTML entities). The **mermaid** skill is the canonical reference for the
full escape table; the most common one here is `#quot;` for quoted labels:
`A[#quot;My Node#quot;]`, `subgraph S[#quot;Title#quot;]`.

**Line breaks are the one exception** — do NOT use `#lt;br/#gt;` (Mermaid decodes it to the *literal text* `<br/>` and shows it in the node). Use the HTML entity `&lt;br/&gt;` instead: the browser decodes it to `<br/>` in the element's text content, which Mermaid then renders as a real line break.

```html
<pre class="mermaid">
graph LR
    A[#quot;First line&lt;br/&gt;Second line#quot;] --> B[#quot;Done#quot;]
</pre>
```

The `.mermaid-wrapper` div provides a white background so diagrams are readable against the dark page.

**Edge/line contrast**: the stock `theme: 'default'` draws edges in faint `~#333` and does not force an opaque light canvas, so on the dark report page connecting lines and arrows nearly disappear. The template avoids this by initializing Mermaid with `theme: 'base'` plus explicit `themeVariables` (a dark `lineColor` and `textColor` on a white `background`) and a `.mermaid-wrapper svg { background:#fff !important; }` rule. Keep both when adapting the template — do not revert to `theme: 'default'` without re-checking edge contrast.

## Syntax Highlighting

highlight.js is loaded from CDN with the Tokyo Night Dark theme (matches the report palette). The template includes the core library but **not** language packs — add the ones you need:

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/go.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/python.min.js"></script>
```

Use `language-*` classes on code blocks:

```html
<pre><code class="language-go">func main() {
    fmt.Println("hello")
}</code></pre>
```

`hljs.highlightAll()` is called at the bottom of the template alongside Mermaid init.

Common language packs: `go`, `python`, `javascript`, `typescript`, `bash`, `json`, `yaml`, `sql`, `ruby`, `rust`, `java`, `diff`.

### Validating diagrams before embedding

Use the **mermaid** skill to validate complex diagrams before putting them in the report. Draft them as `.mmd` files, validate, then paste the content into `<pre class="mermaid">` blocks.

## Rules

- **Always use `/tmp/`** — reports are ephemeral artifacts, not project files
- **Always finalize before opening** — `./tools/inject-annotations.sh` must run on every report before `open`. No exceptions.
- **Self-contained** — no local asset references; use CDN for libraries
- **Read the template** before generating — don't recreate styles from memory
