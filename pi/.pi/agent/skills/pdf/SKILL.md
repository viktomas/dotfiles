---
name: pdf
description: Extract text and tables from PDF files - bank and broker statements, invoices, contracts, scanned documents. Use whenever a task involves reading a .pdf. Keywords - pdf, statement, pdftotext, scanned, OCR, extract text from pdf.
---

# Reading PDFs

Never guess at a PDF and never open it in an app. Extract text to a file and
read that.

## The one command

```sh
pdftotext -layout in.pdf /tmp/in.txt   # then read /tmp/in.txt
pdftotext -layout in.pdf -             # or straight to stdout / a grep
```

`-layout` is not optional for anything with columns — statements, invoices,
tables. Without it the columns interleave and numbers end up on the wrong row.
Other flags worth knowing:

| flag | when |
|---|---|
| `-f N -l M` | only pages N..M — big statements are mostly boilerplate |
| `-raw` | reading order rather than visual layout, for flowing prose |
| `-nopgbrk` | drop the `^L` page breaks before grepping |

`pdftotext` comes from `brew install poppler`, along with `pdfinfo` (page count,
producer) and `pdfimages`.

## Scanned PDFs

If `pdftotext` returns nothing or near-nothing, the pages are images. Rasterise
and OCR (`tesseract` is installed):

```sh
pdftoppm -r 300 -png in.pdf /tmp/pg          # /tmp/pg-1.png, ...
for p in /tmp/pg-*.png; do tesseract "$p" - 2>/dev/null; done > /tmp/in.txt
```

OCR output is *evidence of what the page says*, not the page. Never copy a
figure from OCR into a ledger, invoice or tax file without saying it came from
OCR and eyeballing it.

## Fallback

If poppler is missing and you cannot install it, ghostscript
(`gs -q -dNOPAUSE -dBATCH -sDEVICE=txtwrite -sOutputFile=/tmp/in.txt in.pdf`)
also produces text, but it flattens table columns — use it only to locate a
section, not to transcribe numbers.

## Working with the extracted text

- Extract once to `/tmp/<name>.txt`, then grep and `read` that file. Do not
  re-run the extractor for every question.
- Locate sections by their heading first
  (`grep -n -A20 "SECURITY TRANSFERS" /tmp/x.txt`) rather than reading whole
  statements; a 10-page statement is 90% disclosures.
- Amounts wrap and thousands separators survive: `grep -E "[0-9],[0-9]{3}\."`.

## Where PDFs live around here

`finance/import/<bank>/` (raw bank exports), `finance/gtlb/evidence/` (broker
statements and exercise notices), `finance/invoicing/` (rendered invoices).
The `@ai` agent image has **no PDF tooling** — poppler and ghostscript are not
in any `mise.toml`, so PDF work only happens on my laptop.
