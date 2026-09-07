#!/usr/bin/env python3
"""Decode a `tmux capture-pane -e` dump into per-token colours.

    capture.sh file.ts 30 | decode.py --tiers /tmp/tiers.json
    capture.sh file.ts 30 | decode.py --summary
    capture.sh file.ts 30 | decode.py --svg out.svg --rows 1-28

Pure stdlib. Three views:

  annotate (default)  every token prefixed with its tier name (or raw hex)
  --summary           every colour used, share of painted cells, dE from base
  --svg PATH          the capture as an SVG, exactly as painted

dE is CIE76 against the base colour; ~10 is roughly the just-noticeable
difference for text-sized glyphs, which is the number that matters when you are
deciding whether a tier is actually a signal.
"""

import argparse
import html
import json
import math
import re
import sys
from collections import Counter

SGR = re.compile(r"\x1b\[([0-9;]*)m")


def decode(text):
    """-> [[ (fg|None, bold, italic, chunk), ... ] per row ]"""
    rows = []
    for line in text.split("\n"):
        fg, bold, italic = None, False, False
        segs, buf, i = [], "", 0
        for m in SGR.finditer(line):
            buf += line[i:m.start()]
            i = m.end()
            if buf:
                segs.append((fg, bold, italic, buf))
                buf = ""
            codes = m.group(1).split(";")
            j = 0
            while j < len(codes):
                c = codes[j]
                if c in ("", "0"):
                    fg, bold, italic = None, False, False
                elif c == "1":
                    bold = True
                elif c == "3":
                    italic = True
                elif c == "22":
                    bold = False
                elif c == "23":
                    italic = False
                elif c == "39":
                    fg = None
                elif c == "38" and j + 1 < len(codes) and codes[j + 1] == "2":
                    fg = "#%02x%02x%02x" % tuple(int(x) for x in codes[j + 2:j + 5])
                    j += 4
                j += 1
        buf += line[i:]
        if buf:
            segs.append((fg, bold, italic, buf))
        rows.append(segs)
    return rows


# ---------------------------------------------------------------- colour math
def _lab(hexs):
    r, g, b = (int(hexs[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = f(r), f(g), f(b)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    t = lambda v: v ** (1 / 3) if v > 0.008856 else 7.787 * v + 16 / 116
    fx, fy, fz = t(x), t(y), t(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def dE(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(_lab(a), _lab(b))))


def parse_rows(spec, n):
    if not spec:
        return list(range(1, n + 1))
    out = []
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return [r for r in out if 1 <= r <= n]


# ---------------------------------------------------------------- views
def annotate(rows, names, base):
    for n, segs in rows:
        parts = []
        for fg, bold, italic, txt in segs:
            if not txt.strip():
                parts.append(txt)
                continue
            key = (fg or base, bold, italic)
            label = names.get(key) or names.get((fg or base, False, False)) or (fg or "default")
            label += "+B" if bold else ""
            label += "+I" if italic else ""
            parts.append("[%s]%s" % (label, txt))
        print("%4d %s" % (n, "".join(parts).rstrip()))


def summary(rows, names, base):
    c = Counter()
    for _, segs in rows:
        for fg, bold, italic, txt in segs:
            n = len(txt.strip())
            if n:
                c[(fg or base, bold, italic)] += n
    total = sum(c.values())
    print("%-9s %-8s %6s  %5s  %s" % ("colour", "attrs", "share", "dE", "tier"))
    for (fg, bold, italic), n in c.most_common():
        attrs = ("bold " if bold else "") + ("italic" if italic else "")
        d = dE(base, fg) if fg.startswith("#") else 0.0
        print("%-9s %-8s %5.1f%%  %5.1f  %s" % (
            fg, attrs or "-", 100 * n / total, d,
            names.get((fg, bold, italic), names.get((fg, False, False), "?"))))
    print("\nbase = %s; dE ~10 is the just-noticeable threshold at text sizes" % base)


MONO = "ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"


def to_svg(rows, base, bg, path):
    ch, lh, pad, fs = 8.05, 20, 12, 13.5
    texts = ["".join(s[3] for s in segs).rstrip() for _, segs in rows]
    w = round(max(len(t) for t in texts) * ch + 2 * pad)
    h = len(rows) * lh + 2 * pad
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" '
           'height="%d" role="img">' % (w, h, w, h),
           '  <rect width="%d" height="%d" rx="8" fill="%s"/>' % (w, h, bg)]
    for i, (_, segs) in enumerate(rows):
        y = pad + lh * i + fs
        merged = []
        for fg, bold, italic, txt in segs:
            key = (fg or base, bold, italic)
            if merged and merged[-1][0] == key:
                merged[-1][1] += txt
            else:
                merged.append([key, txt])
        while merged and not merged[-1][1].strip():
            merged.pop()
        spans = []
        for (fg, bold, italic), txt in merged:
            attrs = ' font-weight="700"' if bold else ""
            attrs += ' font-style="italic"' if italic else ""
            spans.append('<tspan fill="%s"%s>%s</tspan>'
                         % (fg, attrs, html.escape(txt).replace(" ", "\u00a0")))
        out.append('  <text x="%d" y="%d" font-family="%s" font-size="%s" '
                   'xml:space="preserve">%s</text>' % (pad, y, MONO, fs, "".join(spans)))
    out.append("</svg>")
    open(path, "w").write("\n".join(out))
    print("wrote %s (%d rows)" % (path, len(rows)), file=sys.stderr)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("pane", nargs="?", help="capture file (default: stdin)")
    p.add_argument("--tiers", help="JSON from tiers.sh")
    p.add_argument("--rows", help="e.g. 3-20,25")
    p.add_argument("--summary", action="store_true")
    p.add_argument("--svg")
    p.add_argument("--base", default=None, help="override base colour")
    p.add_argument("--bg", default=None, help="override background colour")
    a = p.parse_args()

    text = open(a.pane).read() if a.pane else sys.stdin.read()
    rows = decode(text)

    names, base, bg = {}, a.base, a.bg
    if a.tiers:
        t = json.load(open(a.tiers))
        bg = bg or (t.pop("__bg", {}) or {}).get("fg")
        base = base or (t.get("base") or {}).get("fg")
        for name, spec in t.items():
            if spec.get("fg"):
                names[(spec["fg"], bool(spec.get("bold")), bool(spec.get("italic")))] = name
    base = base or "#ffffff"
    bg = bg or "#000000"

    picked = [(n, rows[n - 1]) for n in parse_rows(a.rows, len(rows))]
    if a.svg:
        to_svg(picked, base, bg, a.svg)
    elif a.summary:
        summary(picked, names, base)
    else:
        annotate(picked, names, base)


if __name__ == "__main__":
    main()
