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
4. Open: `open /tmp/<descriptive-name>/report.html`

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

Don't limit yourself to what's in the template. Add custom styles, new component types, different layouts — whatever makes the report clear and visually effective for the content at hand.

## Mermaid Diagrams

Mermaid renders client-side via CDN. Embed diagrams directly in HTML:

```html
<div class="mermaid-wrapper">
<pre class="mermaid">
graph LR
    A["Step 1"] --> B["Step 2"]
    B --> C["Step 3"]
</pre>
</div>
```

The template includes the Mermaid JS CDN and `mermaid.initialize()` at the bottom.

**Important**: The `<pre class="mermaid">` content must be raw Mermaid syntax — no HTML escaping needed. The `.mermaid-wrapper` div provides a white background so diagrams are readable against the dark page.

### Validating diagrams before embedding

Use the **mermaid** skill to validate complex diagrams before putting them in the report. Draft them as `.mmd` files, validate, then paste the content into `<pre class="mermaid">` blocks.

## Rules

- **Always use `/tmp/`** — reports are ephemeral artifacts, not project files
- **Always `open` at the end** — the user expects to see the report in their browser
- **Self-contained** — no local asset references; use CDN for libraries
- **Read the template** before generating — don't recreate styles from memory
