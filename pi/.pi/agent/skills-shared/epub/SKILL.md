---
name: epub
description: Turn a markdown report (or a plain text file) into a validated EPUB 3 book for an e-ink reader. Use whenever I ask for an epub, a book, something to read on the PocketBook/Kobo, or "make this a book". Renders d2 diagrams, SVG, diffs and images to e-ink-friendly grayscale. Keywords - epub, ebook, e-ink, pocketbook, kobo, kindle, epubcheck, mobi, convert report to book.
---

# Reports → EPUB

`mdreport` (the `report` skill) produces HTML for a browser. This produces a book
for a reader with a slow screen and no colour. Same markdown source, different
output — the markdown stays the single source of truth; never hand-edit the EPUB.
Everything a report may contain (d2, svg, diff, code, callouts incl. foldable,
`<details>`) is supported.

Only build a book when I ask for one; a report alone does not need it.

## One command

```sh
~/.pi/agent/skills-shared/epub/scripts/build_epub.py REPORT.md --shots /tmp/shots
```

The defaults suit a report: title from its `# ` heading, output `REPORT.epub` beside it.

| flag | meaning |
|---|---|
| `-o` | output path; defaults to the source with `.epub` |
| `--title` | defaults to the source's first `# ` heading |
| `--author` | defaults to `$EPUB_AUTHOR`, then `git config user.name` |
| `--chapter-level` | heading level that starts a chapter (default `2`; `1` for docs with only `#`) |
| `--layout` | d2 layout: `auto` (default), `dagre`, `elk`, `tala` |
| `--shots DIR` | screenshot every chapter as 600×900 PNG slices so you can *look* at the pages |
| `--work DIR` | keep the unpacked build tree (default: a temp dir); `OEBPS/` is rebuilt each run |
| `--keep-color` | copy referenced raster images without grayscaling or downscaling |
| `--check` | verify an existing book: `--check BOOK.epub --source REPORT.md` |
| `--no-verify` | skip epubcheck and the word comparison |

Take a `.txt` too: its first short line becomes the title, paragraphs are joined,
form feeds split parts. Anything with headings deserves a look at
`--chapter-level` first.

Put the book next to the report (in a task session, in the task's state
directory, beside the `.md`) and add it to the report's line in the state file.
`--work` is worth keeping while you iterate so the d2 sources and probe renders
survive.

### Fixing the source vs. "never edit a report"

The fixes below ("rewrite in the source", "shorten the cell") apply to a report
you are writing *now*. A report that was already written and handed over is a
snapshot (see the `report` skill): do not edit it to please the book. Build it as
is and tell me what reads badly. If it really must change, write a new report
file, mark the old one superseded, and build the book from the new one.

## What the script does

1. **Markdown.** markdown-it-py parses CommonMark + GFM, with footnotes, task
   lists, autolinks, strikethrough, deeply nested lists, and correct parsing of
   markdown inside raw HTML. Code fences stay opaque: a `> [!NOTE]` shown in a
   ```` ```markdown ```` block is left alone.
2. **Callouts.** GFM `> [!NOTE]` / `TIP` / `IMPORTANT` / `WARNING` / `CAUTION`
   become separate boxed blocks with a bold title. `+`/`-` and a custom title
   (`> [!TIP]+ Custom title`) are accepted; the fold state is dropped, so the
   content is always visible on the page. A malformed callout (no space after
   `>`) stays a plain blockquote.
3. **Details.** `<details>` / `<summary>` become visible, always-expanded,
   left-ruled blocks. The markdown inside is parsed and the summary is bold.
   Readers that ignore `<details>` still show the content.
4. **Diffs.** A ```` ```diff ```` fence stays unified: added lines are bold,
   removed lines italic, `@@` hunk headers grey. No colour is needed to read it.
5. **Diagrams.** Every ```` ```d2 ```` block becomes a grayscale PNG. The script
   tries `dagre`/`tala`/`elk` in the written and flipped direction, measures the
   native SVG, and keeps the candidate whose text stays largest when fitted to a
   portrait page. It prints the chosen layout, direction and text scale, and
   warns when the best is still too small to read.
6. **SVG.** A ```` ```svg ```` block is rasterised at 1200 px wide (grayscale,
   `currentColor` → black) and inserted as a full-width figure. A broken SVG
   falls back to the code block with a warning.
7. **Images and links.** Referenced local images are converted to grayscale and
   downscaled to 1200 px (JPEG stays JPEG; SVG references are rasterised).
   Missing images become `[missing image: alt]`. Local links (`.md`, `.sh`, …)
   become their text plus a `<code>` of the target: they cannot open from a
   book, and epubcheck rejects them as fragments. `mailto:`, `http(s)://` and
   `#anchor` links are kept.
8. **Structure.** One chapter per heading of the chosen level, a title page with
   the front matter, a TOC, and internal `#anchor` links rewritten to point at
   the chapter file that now holds that anchor. Heading ids are Unicode-aware
   and added at every level, and footnote links are remapped too.
9. **Checks.** epubcheck, then a word-level comparison against the same
   markdown-it token stream, so a paragraph that got eaten cannot pass as a
   good build. A missing word exits non-zero.

## The two checks that matter

```sh
scripts/build_epub.py report.md -o report.epub --shots /tmp/shots
```

- **`epubcheck: 0 fatals / 0 errors / 0 warnings`** and **`content: N words, all
  present in the book`.** Anything else is a bug in the build or the source, not
  a footnote.
- **Then read two or three of the PNGs in `/tmp/shots`.** `--shots` captures the
  whole chapter and slices it into 600×900 pages, so long chapters produce
  several files (`chapter02-00.png`, `-01`, …). Validity says nothing about
  legibility. What to look for: a diagram squeezed into an unreadable strip, a
  wide table running off the page, a stacked pair of mockups split so that the
  second one is orphaned, a heading stranded at the bottom of a page. Look at
  the last slice of a long chapter too, not only the first.

`WARNING: diagram-NN: N colour/contrast change(s) for grayscale` is not noise.
Colour in a diagram was carrying meaning; rewrite that distinction as a dash
pattern, a label or a border, and rebuild.

`WARNING: diagram-NN: text will be about X pt on the page` means no layout is
readable at page width. Split the diagram, or restructure it so it is not one
long row of boxes.

## Traps, already paid for

| trap | what happens | fix |
|---|---|---|
| d2 value as bare `#hex` | d2 reads `#` as a comment: `missing value after colon` | quote it: `style.fill: "#e6e6e6"` |
| dagre on a container of many nodes | 1:4 strip, unreadable once fitted to width | the script tries tala/elk and flips direction; if it still warns, split the diagram |
| colour used to distinguish d2/SVG shapes | grayscale keeps the tone but loses the meaning | encode it as a dash pattern, a label or a border |
| local link to a `.md`, `.sh` or missing file | epubcheck RSC-007 / RSC-012, the whole build fails | the script keeps the text and target as code; use an `https://` link if it must be clickable |
| grayscale images on a dark theme | dark UI mockups become dark slabs on e-ink | accepted; use `--keep-color` only if colour matters more than the screen |
| table with many columns | columns squashed | four or more columns get a fixed layout; shorten the cell text in the source |
| table has one very long cell | the row overflows or the column squeezes | shorten the cell text in the source; CSS cannot fix it |
| raw HTML in the source | void tags, named entities and `align=` are XML/HTML5 errors | the script closes/normalises them; prefer markdown if the HTML is complicated |
| reading the generated xhtml as a check | it validates and still reads badly | `--shots` and look |

## Dependencies

```sh
brew install d2 imagemagick librsvg epubcheck   # d2, magick, rsvg-convert, epubcheck
```

Python dependencies are declared in the script's PEP 723 header
(`markdown-it-py`, `mdit-py-plugins`, `linkify-it-py`). Running it as
`python3 scripts/build_epub.py …` works when they are installed; if the import
fails the script re-executes itself with `uv run --script` (or
`mise x uv@latest -- uv run --script`), and otherwise prints the install hint:

```sh
python3 -m pip install --user markdown-it-py mdit-py-plugins linkify-it-py
```

`--shots` needs Chrome (`$CHROME_BIN`, `google-chrome`, or the macOS app).
No pandoc, no calibre required. `ebook-convert` is only worth it if you want a
PDF proof of the pagination: `ebook-convert book.epub preview.pdf --paper-size a6`.

## Style

`assets/book.css` is the whole design: Georgia, black on white, one rule under
`h2`, boxed callouts, ruled `details`, a borderless diff with bold/italic
markers, no colour anywhere. Change it there, not in the script, and keep it
grayscale-safe — an e-ink screen renders `#eee` as a muddy grey and anything
coloured as a slightly different muddy grey.
