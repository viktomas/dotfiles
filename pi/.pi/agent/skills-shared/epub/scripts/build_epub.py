#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["markdown-it-py", "mdit-py-plugins", "linkify-it-py"]
# ///
"""Build an EPUB 3 book from a markdown report (or a plain text file).

Designed for e-ink readers: serif body text, black on white, every diagram and
screenshot rendered or scaled so that one fits on one screen.

    build_epub.py REPORT.md -o REPORT.epub --title "..." --author "..."

What it does, in order:

  1. reads the source and parses it with markdown-it-py (CommonMark + GFM);
  2. renders every ```d2 block to a grayscale PNG, choosing the layout and
     direction whose text stays largest on a page; rasterises ```svg blocks and
     normalises referenced images (grayscale, downscaled);
  3. converts markdown to XHTML, turns callouts/details into readable blocks,
     styles diff fences, rewrites intra-document #anchors to point at the right
     chapter file, wraps images in <figure>;
  4. writes nav/TOC + OPF + CSS and zips the EPUB the way the spec wants;
  5. runs epubcheck and compares the book's words against the source's words so
     a silently dropped paragraph cannot pass as a good build.

Only step 5's epistemic job is left to you: look at the screenshots (--shots).
"""

from __future__ import annotations

import argparse
import hashlib
import html as htmllib
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import uuid
import zipfile
from collections import Counter
from datetime import datetime, timezone
from html.entities import name2codepoint
from html.parser import HTMLParser
from pathlib import Path

try:
    import linkify_it as _linkify_it  # required by the gfm-like preset
    from markdown_it import MarkdownIt
    from markdown_it.token import Token
    from mdit_py_plugins.anchors import anchors_plugin
    from mdit_py_plugins.footnote import footnote_plugin
    from mdit_py_plugins.tasklists import tasklists_plugin
except ImportError:  # pragma: no cover - environment problem
    def _reexec_with_uv() -> None:
        """Re-run this script under `uv run --script` so PEP 723 deps exist."""
        if os.environ.get("EPUB_BUILD_REEXEC"):
            sys.exit(
                "error: markdown-it-py is not importable even after re-exec.\n"
                "Try: pip install --user markdown-it-py mdit-py-plugins linkify-it-py"
            )
        self_path = str(Path(__file__).resolve())
        args = sys.argv[1:]

        def works(cmd: list[str]) -> bool:
            try:
                return subprocess.run(
                    cmd, capture_output=True, check=False
                ).returncode == 0
            except OSError:
                return False

        if works(["uv", "--version"]):
            argv = ["uv", "run", "--script", self_path, *args]
        elif works(["mise", "--version"]):
            argv = ["mise", "x", "uv@latest", "--", "uv", "run", "--script", self_path, *args]
        else:
            sys.exit(
                "error: markdown-it-py is missing and neither uv nor mise is available.\n"
                "Install once with: pip install --user markdown-it-py mdit-py-plugins linkify-it-py"
            )
        env = dict(os.environ, EPUB_BUILD_REEXEC="1")
        os.execvpe(argv[0], argv, env)

    _reexec_with_uv()
    raise SystemExit(2)

_LINKIFY = _linkify_it  # keep the dependency probe alive

HERE = Path(__file__).resolve().parent
CSS = (HERE.parent / "assets" / "book.css").read_text(encoding="utf-8")

CALLOUT_LINE = re.compile(
    r"^\s{0,3}>\s+\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]([+-])?(?:[ \t]+(.*?))?[ \t]*$",
    re.I,
)

# A portrait page at a comfortable base font, in CSS pixels. Diagrams are scored
# by how large their text stays when fitted into this box.
PAGE_W, PAGE_H = 560, 800
MIN_EFFECTIVE_SCALE = 0.5  # below this the diagram text is under ~6pt on the page
READABLE_SCALE = 2 / 3      # ~8pt: prefer candidates at or above this
MAX_IMAGE_WIDTH = 1200
DPI = 200

XHTML = """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="{lang}" lang="{lang}">
<head>
<meta charset="utf-8"/>
<title>{title}</title>
<link rel="stylesheet" type="text/css" href="../styles/book.css"/>
</head>
<body>
{body}
</body>
</html>
"""

NAV = """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="{lang}" lang="{lang}">
<head>
<meta charset="utf-8"/>
<title>Contents</title>
<link rel="stylesheet" type="text/css" href="styles/book.css"/>
</head>
<body>
<nav epub:type="toc" id="toc">
<h1>Contents</h1>
<ol>
{items}
</ol>
</nav>
<nav epub:type="landmarks" hidden="hidden">
<ol>
<li><a epub:type="bodymatter" href="text/chapter01.xhtml">Start of content</a></li>
</ol>
</nav>
</body>
</html>
"""

CONTAINER = """<?xml version="1.0" encoding="utf-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles>
<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
</rootfiles>
</container>
"""


# --------------------------------------------------------------------------- #
# small helpers
# --------------------------------------------------------------------------- #

def say(msg: str) -> None:
    print(msg, flush=True)


def warn(msg: str) -> None:
    print(f"WARNING: {msg}", file=sys.stderr, flush=True)


def die(msg: str) -> None:
    sys.exit(f"error: {msg}")


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, capture_output=True, **kw)


def need(tool: str, hint: str) -> str:
    path = shutil.which(tool)
    if not path:
        die(f"{tool} is not installed ({hint})")
    return path


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def image_size(path: Path) -> tuple[int, int]:
    """Width/height for PNG, JPEG or any raster ImageMagick understands."""
    try:
        out = run(["magick", "identify", "-format", "%w %h", str(path)]).stdout.decode().split()
        return int(out[0]), int(out[1])
    except (OSError, subprocess.CalledProcessError, IndexError, ValueError):
        try:
            return png_size(path)
        except (OSError, ValueError):
            return 0, 0


def norm_words(text: str) -> list[str]:
    return re.findall(r"[\w'’@.+/-]+", text)


def plain_text(tokens: list[Token] | None) -> str:
    """Visible text from an inline token's children (for chapter labels)."""
    out: list[str] = []
    for t in tokens or []:
        if t.type in ("text", "code_inline"):
            out.append(t.content)
        elif t.type == "html_inline":
            out.append(html_text(t.content))
    return re.sub(r"\s+", " ", "".join(out)).strip()


def html_text(value: str) -> str:
    value = re.sub(r"<!--.*?-->", "", value, flags=re.S)
    return htmllib.unescape(re.sub(r"<[^>]+>", " ", value))


# --------------------------------------------------------------------------- #
# colour -> grayscale
# --------------------------------------------------------------------------- #

NAMED_RGB = {
    "black": (0, 0, 0), "white": (255, 255, 255),
    "red": (255, 0, 0), "green": (0, 128, 0), "lime": (0, 255, 0),
    "blue": (0, 0, 255), "orange": (255, 165, 0), "yellow": (255, 255, 0),
    "purple": (128, 0, 128), "pink": (255, 192, 203), "teal": (0, 128, 128),
    "cyan": (0, 255, 255), "aqua": (0, 255, 255), "magenta": (255, 0, 255),
    "fuchsia": (255, 0, 255), "brown": (165, 42, 42), "grey": (128, 128, 128),
    "gray": (128, 128, 128), "lightgray": (211, 211, 211),
    "lightgrey": (211, 211, 211), "darkgray": (169, 169, 169),
    "darkgrey": (169, 169, 169), "silver": (192, 192, 192),
    "maroon": (128, 0, 0), "olive": (128, 128, 0), "navy": (0, 0, 128),
}
COLOR_PROP = re.compile(r"(style\.(fill|stroke|font-color)\s*:\s*)([^;}\n]+)")
HEX = re.compile(r"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
STYLE_BLOCK = re.compile(r"\{[^{}]*\}")


def rgb_of(value: str) -> tuple[int, int, int] | None:
    v = value.strip().strip('"').strip("'").lower()
    if v in ("", "none", "transparent", "currentcolor"):
        return None
    if v.startswith("url("):
        return None
    if v.startswith("#"):
        if not HEX.match(v):
            return None
        digits = v[1:]
        if len(digits) == 3:
            return tuple(int(c * 2, 16) for c in digits)  # type: ignore[return-value]
        return int(digits[0:2], 16), int(digits[2:4], 16), int(digits[4:6], 16)
    return NAMED_RGB.get(v)


def luminance(value: str) -> float | None:
    rgb = rgb_of(value)
    if rgb is None:
        return None
    r, g, b = rgb
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def gray_hex(value: str) -> str | None:
    """Luminance-preserving gray for a colour; None when it is not a colour."""
    lum = luminance(value)
    if lum is None:
        return None
    v = min(max(round(lum * 255), 0x20), 0xE8)
    return f"#{v:02x}{v:02x}{v:02x}"


def is_gray(value: str) -> bool:
    rgb = rgb_of(value)
    return rgb is not None and rgb[0] == rgb[1] == rgb[2]


def grayscale_safe(src: str) -> tuple[str, list[str]]:
    """d2 colour carries meaning that grayscale rendering silently loses.

    Map each colour to its own luminance (not one flat grey), then make sure a
    white font never lands on a light fill (or a black font on a dark fill).
    Report the replacements once per diagram so the author can encode the lost
    distinction as a dash pattern or a label.
    """
    changes: list[str] = []

    def repl(m: re.Match) -> str:
        prop, kind, value = m.group(1), m.group(2), m.group(3).strip()
        if is_gray(value):
            return m.group(0)
        gray = gray_hex(value)
        if gray is None:
            return m.group(0)
        changes.append(f"{kind}: {value} -> {gray}")
        return f'{prop}"{gray}"'

    out = COLOR_PROP.sub(repl, src)

    def style_block(m: re.Match) -> str:
        block = m.group(0)
        fill_m = re.search(r"style\.fill\s*:\s*\"?([^;\"]+)\"?", block)
        font_m = re.search(r"style\.font-color\s*:\s*\"?([^;\"]+)\"?", block)
        if fill_m is None:
            return block
        fill_gray = gray_hex(fill_m.group(1))
        fill_lum = luminance(fill_gray) if fill_gray else None
        if fill_lum is None:
            return block
        light_fill = fill_lum > 0.5
        if font_m is not None:
            font_gray = gray_hex(font_m.group(1)) or font_m.group(1)
            font_lum = luminance(font_gray)
            if font_lum is not None and (font_lum > 0.5) == light_fill:
                new = "#000" if light_fill else "#fff"
                block = block[: font_m.start()] + f'style.font-color: "{new}"' + block[font_m.end():]
                changes.append(f"font contrast -> {new}")
        elif not light_fill:
            block = re.sub(r"\s*\}$", '; style.font-color: "#fff"}', block)
            changes.append("font contrast -> #fff")
        return block

    out = STYLE_BLOCK.sub(style_block, out)
    return out, list(dict.fromkeys(changes))


# --------------------------------------------------------------------------- #
# d2 / svg -> grayscale png
# --------------------------------------------------------------------------- #

def svg_size(path: Path) -> tuple[int, int]:
    try:
        head = path.read_text(encoding="utf-8", errors="replace")[:4000]
    except OSError:
        return 0, 0
    m = re.search(r'viewBox="([\d.+-]+)\s+([\d.+-]+)\s+([\d.+-]+)\s+([\d.+-]+)"', head)
    if m:
        return int(float(m.group(3))), int(float(m.group(4)))
    w = re.search(r'\bwidth="([\d.]+)', head)
    h = re.search(r'\bheight="([\d.]+)', head)
    if w and h:
        return int(float(w.group(1))), int(float(h.group(1)))
    return 0, 0


def with_direction(d2_text: str, direction: str) -> str:
    m = re.search(r"(?m)^direction:\s*\w+\s*$", d2_text)
    if m:
        return d2_text[: m.start()] + f"direction: {direction}" + d2_text[m.end():]
    return f"direction: {direction}\n{d2_text}"


def flip_direction(direction: str) -> str:
    return "down" if direction in ("right", "left") else "right"


def render_d2(d2_text: str, out_png: Path, work: Path, layout: str,
              tag: str = "") -> tuple[tuple[int, int], tuple[int, int]]:
    """Render one candidate, returning ((native_w, native_h), (png_w, png_h))."""
    d2 = need("d2", "brew install d2")
    stem = out_png.stem + (f"-{tag}" if tag else "")
    src = work / f"{stem}.d2"
    svg = work / f"{stem}.svg"
    raw = work / f"{stem}.raw.png"
    src.write_text(d2_text, encoding="utf-8")
    run([d2, "--theme", "0", "--layout", layout, str(src), str(svg)])

    rsvg = shutil.which("rsvg-convert")
    if rsvg:
        run([rsvg, "-d", str(DPI), "-p", str(DPI), "-b", "white", str(svg), "-o", str(raw)])
    else:  # ImageMagick's internal SVG renderer loses text occasionally
        magick = need("magick", "brew install imagemagick librsvg")
        run([magick, "-background", "white", "-density", str(DPI), str(svg),
             "-background", "white", "-alpha", "remove", "-alpha", "off", str(raw)])

    magick = shutil.which("magick")
    if magick:
        run([magick, str(raw), "-colorspace", "Gray", "-type", "Grayscale",
             "-resize", f"{MAX_IMAGE_WIDTH}x{MAX_IMAGE_WIDTH}>", "-strip", str(out_png)])
    else:
        shutil.copy2(raw, out_png)
    return svg_size(svg), png_size(out_png)


def best_diagram(d2_text: str, out_png: Path, work: Path,
                 layout_pref: str) -> tuple[int, int, str, str, float]:
    """Pick layout x direction by effective text scale when fitted to a page."""
    layouts = ["dagre", "tala", "elk"] if layout_pref == "auto" else [layout_pref]
    m = re.search(r"(?m)^direction:\s*(\w+)\s*$", d2_text)
    written = m.group(1).lower() if m else "down"
    directions: list[str | None] = [written, flip_direction(written)]
    if m is None:
        # let d2 keep its own default for the first candidate
        directions = [None, "right"]

    candidates = []
    for layout in layouts:
        for direction in directions:
            text = d2_text if direction is None else with_direction(d2_text, direction)
            tag = f"{layout}-{direction or 'default'}"
            probe = work / f"probe-{out_png.stem}-{tag}.png"
            try:
                (nw, nh), (pw, ph) = render_d2(text, probe, work, layout, tag)
            except subprocess.CalledProcessError as exc:
                warn(f"d2 layout {tag} failed for {out_png.stem}: "
                     f"{exc.stderr.decode(errors='replace').strip()[:200]}")
                continue
            if not nw or not nh:
                nw, nh = pw, ph
            scale = min(1.0, PAGE_W / nw, PAGE_H / nh)
            candidates.append((scale, layout, direction or written, probe, pw, ph))
    if not candidates:
        die(f"every d2 layout failed for {out_png.stem}")

    readable = [c for c in candidates if c[0] >= READABLE_SCALE]
    # Dagre is the safest renderer for ordinary flowcharts; require a clearly
    # better scale before switching to another layout.
    pool = readable or candidates
    scale, layout, direction, probe, pw, ph = max(
        pool, key=lambda c: c[0] + (0.02 if c[1] == "dagre" else 0.0))
    shutil.copy2(probe, out_png)
    return pw, ph, layout, direction, scale


def render_svg(svg_text: str, out_png: Path, work: Path) -> tuple[int, int] | None:
    """Rasterise a ```svg block to a grayscale PNG, or None if it cannot."""
    if not re.search(r"<svg\b", svg_text, re.I):
        warn(f"{out_png.stem}: svg block has no <svg> root, left as code")
        return None
    text = svg_text.replace("currentColor", "#000").replace("currentcolor", "#000")
    changes: list[str] = []

    def repl(m: re.Match) -> str:
        attr, value = m.group(1), m.group(2)
        if is_gray(value):
            return m.group(0)
        gray = gray_hex(value)
        if gray is None:
            return m.group(0)
        changes.append(f"{attr}: {value} -> {gray}")
        return f'{attr}="{gray}"'

    text = re.sub(r"\b(fill|stroke)=\"([^\"]*)\"", repl, text)
    if changes:
        warn(f"{out_png.stem}: {len(changes)} svg colour(s) converted to gray; "
             "use a dash pattern or a label if the contrast carried meaning")
    svg = work / f"{out_png.stem}.svg"
    raw = work / f"{out_png.stem}.raw.png"
    svg.write_text(text, encoding="utf-8")
    rsvg = shutil.which("rsvg-convert")
    try:
        if rsvg:
            run([rsvg, "-b", "white", "-w", str(MAX_IMAGE_WIDTH), "--keep-aspect-ratio",
                 str(svg), "-o", str(raw)])
        else:
            magick = need("magick", "brew install imagemagick librsvg")
            run([magick, "-background", "white", str(svg), "-background", "white",
                 "-alpha", "remove", "-alpha", "off", str(raw)])
    except subprocess.CalledProcessError as exc:
        warn(f"{out_png.stem}: rsvg failed, left as code ({exc.stderr.decode()[:120]})")
        return None
    magick = shutil.which("magick")
    if magick:
        run([magick, str(raw), "-colorspace", "Gray", "-type", "Grayscale",
             "-strip", str(out_png)])
    else:
        shutil.copy2(raw, out_png)
    return image_size(out_png)


# --------------------------------------------------------------------------- #
# images
# --------------------------------------------------------------------------- #

def unique_name(images: Path, stem: str, suffix: str) -> Path:
    safe = re.sub(r"[^A-Za-z0-9._-]+", "-", stem).strip("-") or "image"
    out = images / f"{safe}{suffix}"
    if not out.exists():
        return out
    n = 2
    while True:
        out = images / f"{safe}-{n}{suffix}"
        if not out.exists():
            return out
        n += 1


def normalize_image(src: Path, images: Path, work: Path, keep_color: bool,
                    stem: str | None = None) -> Path | None:
    """Copy a referenced raster into the book, grayscale and downscaled."""
    stem = stem or src.stem
    suffix = src.suffix.lower()
    if suffix == ".svg":
        out = unique_name(images, stem, ".png")
        try:
            return out if render_svg(src.read_text(encoding="utf-8"), out, work) else None
        except OSError:
            return None
    if keep_color:
        out = unique_name(images, stem, suffix or ".bin")
        shutil.copy2(src, out)
        return out

    out_suffix = ".jpg" if suffix in (".jpg", ".jpeg") else ".png"
    out = unique_name(images, stem, out_suffix)
    magick = shutil.which("magick")
    if magick:
        cmd = [magick, str(src), "-background", "white", "-alpha", "remove",
               "-alpha", "off", "-colorspace", "Gray", "-resize",
               f"{MAX_IMAGE_WIDTH}x{MAX_IMAGE_WIDTH}>", "-strip"]
        if out_suffix == ".jpg":
            cmd += ["-quality", "85"]
        try:
            run([*cmd, str(out)])
            return out
        except subprocess.CalledProcessError:
            if out.exists():
                out.unlink()
    out = unique_name(images, stem, suffix or ".bin")
    shutil.copy2(src, out)
    return out


def media_type(path: Path) -> str:
    guessed = mimetypes.guess_type(path.name)[0]
    if guessed and guessed.startswith("image/"):
        return guessed
    return "application/octet-stream"


class BuildContext:
    def __init__(self, base: Path, images: Path, work: Path,
                 keep_color: bool = False, dry_run: bool = False):
        self.base = base
        self.images = images
        self.work = work
        self.keep_color = keep_color
        self.dry_run = dry_run
        self.layout_pref = "auto"
        self.used: dict[str, str] = {}
        self.diagrams: dict[str, str] = {}
        self.svgs: dict[str, str] = {}
        self.warned_links: set[str] = set()
        self.missing_images: set[str] = set()

    def register_image(self, ref: str, alt: str = "", stem: str | None = None) -> str | None:
        if ref.startswith(("http://", "https://", "data:")):
            return ref
        raw_ref = urllib.parse.unquote(ref)
        path = Path(raw_ref)
        if not path.is_absolute():
            path = (self.base / path).resolve()
        if not path.exists() or not path.is_file():
            if ref not in self.missing_images:
                warn(f"image not found, replaced with text: {ref}")
                self.missing_images.add(ref)
            return None
        key = str(path)
        if key in self.used:
            return self.used[key]
        if self.dry_run:
            name = path.name
            self.used[key] = f"../images/{name}"
            return self.used[key]
        out = normalize_image(path, self.images, self.work, self.keep_color, stem)
        if out is None:
            if ref not in self.missing_images:
                warn(f"image could not be read, replaced with text: {ref}")
                self.missing_images.add(ref)
            return None
        self.used[key] = f"../images/{out.name}"
        return self.used[key]

    def diagram(self, content: str) -> str | None:
        key = hashlib.sha1(content.encode("utf-8")).hexdigest()
        if key in self.diagrams:
            return self.diagrams[key]
        index = len(self.diagrams) + 1
        name = f"diagram-{index:02d}.png"
        if self.dry_run:
            self.diagrams[key] = name
            return name
        safe, changes = grayscale_safe(content)
        if changes:
            detail = ", ".join(changes[:4]) + (" …" if len(changes) > 4 else "")
            warn(f"diagram-{index:02d}: {len(changes)} colour/contrast change(s) for grayscale "
                 f"({detail}); use a dash pattern or a label if the contrast carried meaning")
        png = self.images / name
        w, h, layout, direction, scale = best_diagram(safe, png, self.work, self.layout_pref)
        say(f"diagram {index}: {name} {w}x{h} "
            f"(layout {layout}/{direction}, text scale {scale:.2f})")
        if scale < MIN_EFFECTIVE_SCALE:
            warn(f"diagram-{index:02d}: text will be about {12 * scale:.1f} pt on the page; "
                 "restructure it or split it into two diagrams")
        self.diagrams[key] = name
        return name

    def svg(self, content: str) -> str | None:
        key = hashlib.sha1(content.encode("utf-8")).hexdigest()
        if key in self.svgs:
            return self.svgs[key]
        index = len(self.svgs) + 1
        name = f"svg-{index:02d}.png"
        if self.dry_run:
            self.svgs[key] = name
            return name
        out = render_svg(content, self.images / name, self.work)
        if out is None:
            return None
        self.svgs[key] = name
        return name


# --------------------------------------------------------------------------- #
# markdown-it: callouts, details, links, images, fences
# --------------------------------------------------------------------------- #

def make_title_tokens(title: str, level: int) -> list[Token]:
    open_ = Token("paragraph_open", "p", 1, level=level)
    open_.attrs = {"class": "callout-title"}
    inline = Token("inline", "", 0, level=level + 1)
    inline.content = title
    child = Token("text", "", 0)
    child.content = title
    inline.children = [child]
    close = Token("paragraph_close", "p", -1, level=level)
    return [open_, inline, close]


def find_blockquote_close(tokens: list[Token], start: int) -> int:
    depth = 0
    for i in range(start, len(tokens)):
        if tokens[i].type == "blockquote_open":
            depth += 1
        elif tokens[i].type == "blockquote_close":
            depth -= 1
            if depth == 0:
                return i
    return len(tokens) - 1


def apply_callouts(tokens: list[Token], state) -> None:
    lines = state.src.splitlines()
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token.type != "blockquote_open" or not token.map:
            i += 1
            continue
        close = find_blockquote_close(tokens, i)
        line_no = token.map[0]
        raw_line = lines[line_no] if line_no < len(lines) else ""
        m = CALLOUT_LINE.match(raw_line)
        if not m:
            i = close + 1
            continue
        kind = m.group(1).upper()
        fold = m.group(2)
        rest = (m.group(3) or "").strip()

        j = i + 1
        while j < close and tokens[j].type != "inline":
            j += 1
        if j >= close:
            i = close + 1
            continue
        inline = tokens[j]
        first, sep, remainder = inline.content.partition("\n")
        if fold:
            new_content = remainder if sep else ""
        else:
            new_content = re.sub(
                r"^\s*\[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][+-]?[ \t]*",
                "", first, flags=re.I) + (sep + remainder if sep else "")

        p_open = j - 1 if tokens[j - 1].type == "paragraph_open" else None
        p_close = j + 1 if j + 1 < len(tokens) and tokens[j + 1].type == "paragraph_close" else None

        token.attrs["class"] = f"callout callout-{kind.lower()}"
        title = rest if (fold and rest) else kind.capitalize()
        title_tokens = make_title_tokens(title, token.level + 1)
        tokens[i + 1:i + 1] = title_tokens
        j += len(title_tokens)
        p_open = p_open + len(title_tokens) if p_open is not None else None
        p_close = p_close + len(title_tokens) if p_close is not None else None
        close += len(title_tokens)

        inline = tokens[j]
        inline.content = new_content
        if inline.children is not None:
            inline.children.clear()
            state.md.inline.parse(new_content, state.md, state.env, inline.children)

        if not new_content.strip() and p_open is not None and p_close is not None:
            del tokens[p_open:p_close + 1]
            close -= p_close + 1 - p_open
        i = close + 1


SUMMARY = re.compile(r"<summary\b[^>]*>(.*?)</summary\s*>", re.I | re.S)


def fix_details_html(value: str) -> str:
    value = re.sub(r"<details\b[^>]*>", '<div class="details">', value, flags=re.I)
    value = re.sub(r"</details\s*>", "</div>", value, flags=re.I)
    value = SUMMARY.sub(
        lambda m: f'<p class="summary"><strong>{m.group(1).strip()}</strong></p>', value)
    return value


RAW_IMG = re.compile(r"<img\b[^>]*>", re.I)
SRC_ATTR = re.compile(r"(?<!\S)src\s*=\s*([\"'])(.*?)\1", re.I | re.S)
ALT_ATTR = re.compile(r"(?<!\S)alt\s*=\s*([\"'])(.*?)\1", re.I | re.S)


def rewrite_raw_images(value: str, ctx: BuildContext) -> str:
    def repl(m: re.Match) -> str:
        tag = m.group(0)
        src_m = SRC_ATTR.search(tag)
        if src_m is None:
            return tag
        alt_m = ALT_ATTR.search(tag)
        alt = htmllib.unescape(alt_m.group(2)) if alt_m else ""
        new_src = ctx.register_image(src_m.group(2), alt)
        if new_src is None:
            return f"<em>[missing image: {htmllib.escape(alt)}]</em>"
        return tag[:src_m.start()] + f'src="{htmllib.escape(new_src, quote=True)}"' + tag[src_m.end():]

    return RAW_IMG.sub(repl, value)


RAW_A = re.compile(r"<a\b([^>]*?(?<!\S)href\s*=\s*([\"'])([^\"']+)\2[^>]*)>(.*?)</a\s*>", re.I | re.S)
RAW_A_OPEN = re.compile(r"^\s*<a\b([^>]*)>\s*$", re.I | re.S)
RAW_A_CLOSE = re.compile(r"^\s*</a\s*>\s*$", re.I | re.S)
HREF_ATTR = re.compile(r"(?<!\S)href\s*=\s*([\"'])(.*?)\1", re.I | re.S)


def local_target(href: str) -> bool:
    low = href.lower()
    if low.startswith(("#", "http://", "https://", "mailto:")):
        return False
    return True


def rewrite_raw_links(value: str, ctx: BuildContext) -> str:
    def repl(m: re.Match) -> str:
        href = m.group(3)
        text = m.group(4)
        if not local_target(href):
            return m.group(0)
        if href not in ctx.warned_links:
            warn(f"local link kept as text (it cannot open from the book): {href}")
            ctx.warned_links.add(href)
        return f'{text} <code>{htmllib.escape(href)}</code>'

    return RAW_A.sub(repl, value)


def fix_html_token(token: Token, ctx: BuildContext) -> None:
    token.content = fix_details_html(token.content)
    token.content = rewrite_raw_images(token.content, ctx)
    token.content = rewrite_raw_links(token.content, ctx)
    if "task-list-item-checkbox" in token.content:
        checked = 'checked="checked"' in token.content
        token.content = "☑" if checked else "☐"


def sanitize_inline(inline: Token, ctx: BuildContext) -> None:
    children = inline.children or []
    pending_raw_links: list[str] = []
    for child in children:
        if child.type == "image":
            src = child.attrGet("src") or ""
            alt = child.attrGet("alt") or ""
            new_src = ctx.register_image(src, alt)
            if new_src is None:
                child.type = "html_inline"
                child.content = f"<em>[missing image: {htmllib.escape(alt)}]</em>"
                child.attrs = {}
            else:
                child.attrSet("src", new_src)
        elif child.type == "html_inline":
            fix_html_token(child, ctx)
            opening = RAW_A_OPEN.match(child.content)
            if opening:
                href_m = HREF_ATTR.search(opening.group(1))
                if href_m and local_target(href_m.group(2)):
                    href = href_m.group(2)
                    if href not in ctx.warned_links:
                        warn(f"local link kept as text (it cannot open from the book): {href}")
                        ctx.warned_links.add(href)
                    pending_raw_links.append(href)
                    child.content = ""
                    continue
            if pending_raw_links and RAW_A_CLOSE.match(child.content):
                child.content = f" <code>{htmllib.escape(pending_raw_links.pop())}</code>"

    i = 0
    while i < len(children):
        child = children[i]
        if child.type != "link_open":
            i += 1
            continue
        href = child.attrGet("href") or ""
        if not local_target(href):
            i += 1
            continue
        close = i + 1
        while close < len(children) and children[close].type != "link_close":
            close += 1
        if close >= len(children):
            i += 1
            continue
        if href not in ctx.warned_links:
            warn(f"local link kept as text (it cannot open from the book): {href}")
            ctx.warned_links.add(href)
        child.type = "html_inline"
        child.content = ""
        child.attrs = {}
        end = children[close]
        end.type = "html_inline"
        end.content = f" <code>{htmllib.escape(href)}</code>"
        end.attrs = {}
        i = close + 1


def finalize_tokens(state) -> None:
    """Runs after the inline pass: callouts, details, tasklists, links, images."""
    ctx: BuildContext = state.env["ctx"]
    apply_callouts(state.tokens, state)
    for token in state.tokens:
        if token.type in ("html_block", "html_inline"):
            fix_html_token(token, ctx)
        elif token.type == "inline":
            sanitize_inline(token, ctx)


def make_md(ctx: BuildContext) -> MarkdownIt:
    md = MarkdownIt("gfm-like", {"html": True, "xhtml_out": True, "linkify": True})
    md.use(footnote_plugin).use(tasklists_plugin).use(anchors_plugin, max_level=6)
    md.core.ruler.push("book-final", finalize_tokens)

    default_fence = md.renderer.rules["fence"]

    def fence(tokens, idx, options, env):
        token = tokens[idx]
        info = token.info.strip().split()
        lang = info[0].lower() if info else ""
        if lang == "d2":
            name = env["ctx"].diagram(token.content)
            if name:
                return (f'<figure class="wide">\n'
                        f'<img src="../images/{name}" alt="Diagram" />\n</figure>\n')
        elif lang == "svg":
            name = env["ctx"].svg(token.content)
            if name:
                return (f'<figure class="wide">\n'
                        f'<img src="../images/{name}" alt="SVG figure" />\n</figure>\n')
        elif lang in ("diff", "patch"):
            return render_diff(token.content)
        return default_fence(tokens, idx, options, env)

    md.renderer.rules["fence"] = fence
    return md


def render_diff(content: str) -> str:
    lines = content.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    out: list[str] = ['<pre class="diff"><code>']
    for line in lines:
        if line.startswith("@@"):
            cls = "hunk"
        elif line.startswith(("+++", "---", "diff ", "index ", "\\ No newline")):
            cls = "meta"
        elif line.startswith("+"):
            cls = "add"
        elif line.startswith("-"):
            cls = "del"
        else:
            cls = "ctx"
        out.append(f'<span class="{cls}">{htmllib.escape(line)}</span>')
    out.append("</code></pre>\n")
    return "".join(out)


# --------------------------------------------------------------------------- #
# XHTML safety and figures
# --------------------------------------------------------------------------- #

VOID = ("area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr")
ENTITY = re.compile(r"&([A-Za-z][A-Za-z0-9]+);")
TAG = re.compile(r"<([A-Za-z][\w-]*)([^>]*)>")
ALIGN = re.compile(r"(?<!\S)align\s*=\s*([\"'])(.*?)\1", re.I)
STYLE_ATTR = re.compile(r"(?<!\S)style\s*=\s*([\"'])(.*?)\1", re.I)


def fix_align_attrs(body: str) -> str:
    """`align` was removed from HTML5; epubcheck rejects it (RSC-005)."""

    def tag(m: re.Match) -> str:
        name, attrs = m.group(1), m.group(2)
        am = ALIGN.search(attrs)
        if not am:
            return m.group(0)
        value = am.group(2).strip().lower()
        attrs = attrs[: am.start()] + attrs[am.end():]
        decl = f"text-align:{value}"
        self_closing = attrs.rstrip().endswith("/")
        if self_closing:
            attrs = attrs.rstrip()[:-1].rstrip()
        sm = STYLE_ATTR.search(attrs)
        if sm:
            attrs = attrs[: sm.start()] + f'style="{sm.group(2)}; {decl}"' + attrs[sm.end():]
        else:
            attrs = attrs.rstrip() + f' style="{decl}"'
        return f"<{name}{attrs}{' /' if self_closing else ''}>"


    return TAG.sub(tag, body)


def fix_entities(body: str) -> str:
    def repl(m: re.Match) -> str:
        name = m.group(1)
        if name in ("amp", "lt", "gt", "quot", "apos"):
            return m.group(0)
        code = name2codepoint.get(name)
        if code is None:
            warn(f"unknown HTML entity &{name}; escaped")
            return f"&amp;{name};"
        return f"&#{code};"

    return ENTITY.sub(repl, body)


def fix_xhtml(body: str) -> str:
    body = fix_align_attrs(body)
    for tag in VOID:
        body = re.sub(rf"<{tag}\b([^>]*?)\s*/?>", rf"<{tag}\1 />", body, flags=re.I)
    return fix_entities(body)


def wrap_figures(body: str, images: Path) -> str:
    """Every image becomes a <figure>; a paragraph of images stays one figure."""

    def shape(src: str) -> str:
        name = Path(src).name
        w, h = image_size(images / name)
        return "tall" if h > w * 1.5 else "wide"

    def one_group(srcs: list[str], alts: list[str]) -> str:
        cls = "multi" if len(srcs) > 1 else shape(srcs[0])
        inner = "\n".join(
            f'<img src="{s}" alt="{htmllib.escape(alt, quote=True)}" />'
            for s, alt in zip(srcs, alts)
        )
        return f'<figure class="{cls}">\n{inner}\n</figure>'

    def paragraph(m: re.Match) -> str:
        block = m.group(0)
        srcs = re.findall(r'<img\b[^>]*src="([^"]+)"', block)
        alts = re.findall(r'<img\b[^>]*alt="([^"]*)"', block)
        alts += [""] * (len(srcs) - len(alts))
        return one_group(srcs, alts)

    def bare(m: re.Match) -> str:
        src = re.search(r'src="([^"]+)"', m.group(0))
        alt = re.search(r'alt="([^"]*)"', m.group(0))
        if src is None:
            return m.group(0)
        return (f'<figure class="{shape(src.group(1))}">\n'
                f'<img src="{src.group(1)}" alt="{htmllib.escape(alt.group(1) if alt else "", quote=True)}" />\n'
                f"</figure>")

    # Process only text outside existing <figure> blocks, so a diagram's own
    # figure is not wrapped a second time. Paragraph groups become figures, so
    # split again before handling a bare <img> on its own line.
    out: list[str] = []
    pieces = re.split(r"(<figure\b.*?</figure>)", body, flags=re.S | re.I)
    for i, piece in enumerate(pieces):
        if i % 2:
            out.append(piece)
            continue
        piece = re.sub(r"<p>\s*(?:<img\b[^>]*>\s*)+</p>", paragraph, piece, flags=re.I)
        for j, sub in enumerate(re.split(r"(<figure\b.*?</figure>)", piece, flags=re.S | re.I)):
            out.append(sub if j % 2 else re.sub(r"^<img\b[^>]*>\s*$", bare, sub, flags=re.M))
    return "".join(out)


def style_tables(body: str) -> str:
    """Give wide tables a fixed layout so long tokens cannot squash columns."""

    def repl(m: re.Match) -> str:
        table = m.group(0)
        first_row = re.search(r"<tr\b[^>]*>(.*?)</tr>", table, re.S | re.I)
        if not first_row:
            return table
        cols = len(re.findall(r"<t[hd]\b", first_row.group(1), re.I))
        if cols >= 4 and "class=" not in table.split(">", 1)[0]:
            table = table.replace("<table>", '<table class="many-cols">', 1)
        return table

    return re.sub(r"<table\b[^>]*>.*?</table>", repl, body, flags=re.S | re.I)


# --------------------------------------------------------------------------- #
# plain text input
# --------------------------------------------------------------------------- #

def text_to_markdown(raw: str, title: str | None) -> tuple[str, str | None]:
    """A .txt file: first line is the title if it is short, form feeds split parts."""
    chunks = [c.strip() for c in re.split(r"\x0c", raw) if c.strip()]
    lines = chunks[0].splitlines()
    if title is None and lines and len(lines[0].strip()) <= 90:
        title = lines[0].strip()
        chunks[0] = "\n".join(lines[1:]).strip()
    parts = []
    for i, chunk in enumerate(chunks, start=1):
        head = f"Part {i}"
        body = chunk
        first, _, rest = chunk.partition("\n")
        if len(first.strip()) <= 90 and first.strip() and not first.strip().endswith((".", ":", ",", ";")):
            head, body = first.strip(), rest
        parts.append(f"## {head}\n\n" + "\n\n".join(
            p.strip().replace("\n", " ") for p in re.split(r"\n\s*\n", body) if p.strip()))
    return "\n\n".join(parts), title


# --------------------------------------------------------------------------- #
# source -> document structure
# --------------------------------------------------------------------------- #

def parse_source(src_path: Path, title: str | None) -> tuple[str, str]:
    raw = src_path.read_text(encoding="utf-8")
    if src_path.suffix.lower() == ".txt":
        raw, title = text_to_markdown(raw, title)
    if title is None:
        m = re.search(r"^#\s+(.+)$", raw, flags=re.M)
        title = m.group(1).strip() if m else src_path.stem.replace("-", " ").replace("_", " ")
    return raw, title


def split_chapters(tokens: list[Token], level: int) -> tuple[list[Token], list[dict], str]:
    """Split the token stream at top-level headings; return front, chapters, title id."""
    heads = [i for i, t in enumerate(tokens)
             if t.type == "heading_open" and t.tag == f"h{level}" and t.level == 0]
    title_id = ""
    first_h1 = None
    for i, t in enumerate(tokens):
        if t.type == "heading_open" and t.tag == "h1" and t.level == 0:
            title_id = t.attrGet("id") or ""
            first_h1 = i
            break

    if not heads:
        body = list(tokens)
        if first_h1 is not None and first_h1 + 2 < len(body):
            del body[first_h1:first_h1 + 3]
        return [], [{"id": "content", "title": "", "tokens": body}], title_id

    front = list(tokens[: heads[0]])
    if first_h1 is not None and first_h1 < heads[0]:
        del front[first_h1:first_h1 + 3]
    chapters = []
    for n, start in enumerate(heads):
        end = heads[n + 1] if n + 1 < len(heads) else len(tokens)
        chunk = list(tokens[start:end])
        heading_inline = next((t for t in chunk if t.type == "inline"), None)
        label = plain_text(heading_inline.children if heading_inline else None)
        chapters.append({
            "id": tokens[start].attrGet("id") or f"chapter-{n + 1}",
            "title": label,
            "tokens": chunk,
        })
    return front, chapters, title_id


def rewrite_anchors(text: str, id_to_file: dict[str, str]) -> tuple[str, list[str]]:
    broken: list[str] = []

    def repl(m: re.Match) -> str:
        raw_frag = m.group(1)
        frag = urllib.parse.unquote(raw_frag)
        target = id_to_file.get(frag)
        if target is None:
            broken.append(frag)
            return m.group(0)
        return f'href="{target}#{frag}"'

    return re.sub(r'href="#([^"]+)"', repl, text), broken


# --------------------------------------------------------------------------- #
# EPUB writing
# --------------------------------------------------------------------------- #

def write_epub(out: Path, work: Path, oebps: Path, text_dir: Path, images: Path,
               styles: Path, meta: Path, title: str, author: str, lang: str,
               front_html: str, chapters: list[dict], title_id: str,
               broken: list[str]) -> None:
    book_id = "urn:uuid:" + str(uuid.uuid5(uuid.NAMESPACE_URL, f"{out.name}:{title}"))
    byline = f'<p class="byline">by {htmllib.escape(author)}</p>\n' if author else ""
    h1_id = f' id="{title_id}"' if title_id else ""
    title_body = (f'<section class="title-page" epub:type="titlepage">\n'
                  f"<h1{h1_id}>{htmllib.escape(title)}</h1>\n{byline}{front_html}\n</section>")
    (text_dir / "titlepage.xhtml").write_text(
        XHTML.format(lang=lang, title=htmllib.escape(title), body=title_body), encoding="utf-8")

    pages = [("text/titlepage.xhtml", "titlepage", "Title page")]
    for i, ch in enumerate(chapters, start=1):
        page = f'<section epub:type="chapter">\n{ch["html"]}\n</section>'
        (text_dir / ch["file"]).write_text(
            XHTML.format(lang=lang, title=htmllib.escape(ch["title"], quote=False), body=page),
            encoding="utf-8")
        pages.append((f'text/{ch["file"]}', f"chap{i}", ch["title"]))

    items = "\n".join(f'<li><a href="{href}">{htmllib.escape(label, quote=False)}</a></li>'
                      for href, _id, label in pages)
    (oebps / "nav.xhtml").write_text(NAV.format(lang=lang, items=items), encoding="utf-8")
    (styles / "book.css").write_text(CSS, encoding="utf-8")

    manifest = ['<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
                '<item id="css" href="styles/book.css" media-type="text/css"/>']
    manifest += [f'<item id="{ident}" href="{href}" media-type="application/xhtml+xml"/>'
                 for href, ident, _label in pages]
    for n, p in enumerate(sorted(images.iterdir()), start=1):
        if not p.is_file():
            continue
        ident = f"img-{n:02d}-" + re.sub(r"[^a-z0-9]+", "-", p.stem.lower())
        manifest.append(f'<item id="{ident}" href="images/{p.name}" '
                        f'media-type="{media_type(p)}"/>')

    modified = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    creator = f"<dc:creator>{htmllib.escape(author)}</dc:creator>\n" if author else ""
    opf = f"""<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="{lang}">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="bookid">{book_id}</dc:identifier>
<dc:title>{htmllib.escape(title)}</dc:title>
{creator}<dc:language>{lang}</dc:language>
<meta property="dcterms:modified">{modified}</meta>
</metadata>
<manifest>
{chr(10).join(manifest)}
</manifest>
<spine>
{chr(10).join(f'<itemref idref="{ident}"/>' for _href, ident, _label in pages)}
</spine>
</package>
"""
    (oebps / "content.opf").write_text(opf, encoding="utf-8")
    (meta / "container.xml").write_text(CONTAINER, encoding="utf-8")

    if broken:
        warn(f"anchor(s) point at nothing in the book: {', '.join(sorted(set(broken)))}")
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w") as z:
        info = zipfile.ZipInfo("mimetype")          # must come first, uncompressed
        info.compress_type = zipfile.ZIP_STORED
        z.writestr(info, "application/epub+zip")
        for path in [meta / "container.xml"] + sorted(oebps.rglob("*")):
            if path.is_file():
                z.write(path, path.relative_to(work), compress_type=zipfile.ZIP_DEFLATED)


# --------------------------------------------------------------------------- #
# verify
# --------------------------------------------------------------------------- #

class _Text(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("head", "style", "script"):
            self.skip += 1

    def handle_endtag(self, tag):
        if tag in ("head", "style", "script") and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)


def drop_title_heading(tokens: list[Token]) -> list[Token]:
    """The leading top-level h1 becomes the title page, not body content."""
    out: list[Token] = []
    skipping = False
    seen_heading = False
    for t in tokens:
        if t.type == "heading_open" and t.level == 0:
            if t.tag == "h1" and not seen_heading:
                skipping = True
            seen_heading = True
        if skipping:
            if t.type == "heading_close" and t.tag == "h1":
                skipping = False
            continue
        out.append(t)
    return out


def expected_words(tokens: list[Token]) -> list[str]:
    words: list[str] = []

    def inline(children: list[Token] | None) -> None:
        for t in children or []:
            if t.type in ("text", "code_inline"):
                words.extend(norm_words(t.content))
            elif t.type == "html_inline":
                words.extend(norm_words(html_text(t.content)))
            elif t.type == "footnote_ref":
                # the renderer displays a number, not the source label
                words.extend(norm_words(str(int(t.meta.get("id", 0)) + 1)))
            # image alt text is not visible in the book; footnote backrefs are arrows

    for t in tokens:
        if t.type == "inline":
            inline(t.children)
        elif t.type == "fence":
            info = t.info.strip().split()
            if not info or info[0].lower() not in ("d2", "svg"):
                words.extend(norm_words(t.content))
        elif t.type == "code_block":
            words.extend(norm_words(t.content))
        elif t.type in ("html_block", "html_inline"):
            words.extend(norm_words(html_text(t.content)))
        elif t.type == "footnote_ref":
            words.extend(norm_words(str(int(t.meta.get("id", 0)) + 1)))
    return words


def book_words(text_dir: Path) -> list[str]:
    words: list[str] = []
    for path in sorted(text_dir.glob("*.xhtml")):
        value = path.read_text(encoding="utf-8")
        value = re.sub(r"<head>.*?</head>", "", value, flags=re.S)
        value = re.sub(r'<p class="byline">.*?</p>', "", value, flags=re.S)
        parser = _Text()
        parser.feed(value)
        words.extend(norm_words(" ".join(parser.parts)))
    return words


def verify(out: Path, text_dir: Path, tokens: list[Token],
           title: str = "", author: str = "",
           drop_first_h1: bool = False) -> bool:
    """epubcheck, plus a word-level diff so nothing in the source is silently lost."""
    ok = True
    checker = shutil.which("epubcheck")
    if checker:
        res = subprocess.run([checker, str(out)], capture_output=True, text=True)
        output = res.stdout + res.stderr
        summary = [l for l in output.splitlines() if l.startswith("Messages:")]
        say(f"epubcheck: {summary[-1] if summary else 'no summary line'}")
        counts = re.search(r"(\d+) fatals? / (\d+) errors? / (\d+) warnings?", summary[-1]) if summary else None
        if counts and (int(counts.group(1)) or int(counts.group(2))):
            print(output[-4000:], file=sys.stderr)
            warn("epubcheck reported errors")
            ok = False
        elif res.returncode != 0:
            print(output[-4000:], file=sys.stderr)
            warn("epubcheck failed")
            ok = False
    else:
        warn("epubcheck not installed, validity unchecked (brew install epubcheck)")

    if drop_first_h1:
        tokens = drop_title_heading(tokens)
    src_words = [w.lower() for w in expected_words(tokens)]
    got_words = [w.lower() for w in book_words(text_dir)]
    missing = Counter(src_words) - Counter(got_words)
    extra = Counter(got_words) - Counter(src_words)
    head_words = Counter(w.lower() for w in norm_words(f"{title} {author}"))
    extra = Counter({w: n for w, n in (extra - head_words).items() if n > 0})

    if missing:
        sample = ", ".join(f"{w!r}" + (f" x{n}" if n > 1 else "") for w, n in missing.most_common(15))
        warn(f"words missing from the book ({sum(missing.values())}): {sample}")
        warn(f"content check: {len(src_words)} source words vs {len(got_words)} book words")
        ok = False
    else:
        say(f"content: {len(src_words)} words, all present in the book")
    if extra:
        sample = ", ".join(f"{w!r}" + (f" x{n}" if n > 1 else "") for w, n in extra.most_common(15))
        warn(f"words added by the build ({sum(extra.values())}): {sample}")
    return ok


# --------------------------------------------------------------------------- #
# screenshots
# --------------------------------------------------------------------------- #

def shots(dest: Path, text_dir: Path, chapters: list[dict]) -> None:
    """Full-height chapter screenshots, sliced into page-sized PNGs."""
    chrome = (os.environ.get("CHROME_BIN")
              or shutil.which("google-chrome")
              or ("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
                  if Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome").exists() else None))
    if not chrome:
        warn("no Chrome found, no screenshots (set CHROME_BIN)")
        return
    dest.mkdir(parents=True, exist_ok=True)
    pages = ["titlepage"] + [c["file"].removesuffix(".xhtml") for c in chapters]
    magick = shutil.which("magick")
    for page in pages:
        whole = dest / f".{page}-full.png"
        run([chrome, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
             "--force-device-scale-factor=1", "--window-size=600,20000",
             f"--screenshot={whole}", f"file://{text_dir / (page + '.xhtml')}"])
        if not magick:
            whole.rename(dest / f"{page}.png")
            continue
        try:
            info = run([magick, str(whole), "-fuzz", "2%", "-format", "%@", "info:"]).stdout.decode()
            bbox = re.match(r"(\d+)x(\d+)\+(\d+)\+(\d+)", info.strip())
            height = int(bbox.group(4)) + int(bbox.group(2)) if bbox else 20000
        except (subprocess.CalledProcessError, AttributeError):
            height = 20000
        height = min(max(height, 900), 20000)
        run([magick, str(whole), "-crop", f"600x{height}+0+0", "+repage",
             "-crop", "600x900", "+repage", str(dest / f"{page}-%02d.png")])
        whole.unlink()
    say(f"screenshots: {len(pages)} pages sliced in {dest}")


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build an EPUB 3 book from a markdown report.")
    p.add_argument("src", type=Path, help="source .md (or .txt) file, or .epub with --check")
    p.add_argument("-o", "--out", type=Path, help="output .epub (default: next to the source)")
    p.add_argument("--title", help="book title (default: the source's first # heading)")
    p.add_argument("--author", help="book author (default: $EPUB_AUTHOR, git user.name, or none)")
    p.add_argument("--lang", default="en", help="language tag (default: en)")
    p.add_argument("--chapter-level", type=int, default=2,
                   help="heading level that starts a chapter (default: 2, i.e. ##)")
    p.add_argument("--layout", default="auto", choices=["auto", "dagre", "elk", "tala"],
                   help="d2 layout; auto tries dagre/tala/elk and both directions")
    p.add_argument("--work", type=Path, help="scratch directory (default: an EPUB build temp dir)")
    p.add_argument("--shots", type=Path, help="also write chapter PNG slices here (needs Chrome)")
    p.add_argument("--keep-color", action="store_true",
                   help="do not convert referenced raster images to grayscale")
    p.add_argument("--no-verify", action="store_true", help="skip epubcheck and the word comparison")
    p.add_argument("--check", action="store_true",
                   help="only verify an existing .epub (use --source for the word comparison)")
    p.add_argument("--source", type=Path, help="markdown source for --check's word comparison")
    return p.parse_args(argv)


def default_author() -> str:
    env = os.environ.get("EPUB_AUTHOR")
    if env:
        return env
    try:
        return run(["git", "config", "user.name"]).stdout.decode().strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def check_only(args: argparse.Namespace) -> int:
    epub = args.src.resolve()
    if not epub.exists():
        die(f"no such file: {epub}")
    source = (args.source or epub.with_suffix(".md")).resolve()
    if not source.exists():
        die(f"no source to compare against: {source} (use --source)")
    raw, title = parse_source(source, args.title)
    work = Path(tempfile.mkdtemp(prefix="epub-check-"))
    with zipfile.ZipFile(epub) as z:
        z.extractall(work)
    text_dir = work / "OEBPS" / "text"
    ctx = BuildContext(source.parent, work / "images", work, dry_run=True)
    ctx.layout_pref = args.layout
    md = make_md(ctx)
    tokens = md.parse(raw, {"ctx": ctx})
    return 0 if verify(epub, text_dir, tokens, title, args.author or default_author(),
                       drop_first_h1=args.chapter_level != 1) else 1


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.check:
        return check_only(args)

    src_path: Path = args.src.resolve()
    if not src_path.exists():
        die(f"no such file: {src_path}")
    raw, title = parse_source(src_path, args.title)
    author = args.author if args.author is not None else default_author()

    out: Path = (args.out or src_path.with_suffix(".epub")).resolve()
    work = (args.work or Path(tempfile.mkdtemp(prefix="epub-build-"))).resolve()
    # A reused --work tree may hold chapters and images from an older build.
    for stale in (work / "OEBPS", work / "META-INF"):
        if stale.exists():
            shutil.rmtree(stale)
    oebps, text_dir, images, styles = (work / "OEBPS" / d for d in ("", "text", "images", "styles"))
    meta = work / "META-INF"
    for d in (text_dir, images, styles, meta):
        d.mkdir(parents=True, exist_ok=True)

    ctx = BuildContext(src_path.parent, images, work, keep_color=args.keep_color)
    ctx.layout_pref = args.layout
    md = make_md(ctx)
    tokens = md.parse(raw, {"ctx": ctx})

    front_tokens, chapter_tokens, title_id = split_chapters(tokens, args.chapter_level)
    front_html = md.renderer.render(front_tokens, md.options, {"ctx": ctx}).strip() if front_tokens else ""

    chapters: list[dict] = []
    for ch in chapter_tokens:
        html = md.renderer.render(ch["tokens"], md.options, {"ctx": ctx}).strip()
        html = wrap_figures(html, images)
        html = style_tables(html)
        html = fix_xhtml(html)
        label = ch["title"] or title
        if not ch["title"]:
            # a single chapter (no headings at the chosen level) uses the book title
            label = title
        chapters.append({"id": ch["id"], "title": label, "html": html})

    front_html = wrap_figures(front_html, images) if front_html else ""
    front_html = style_tables(front_html) if front_html else ""
    front_html = fix_xhtml(front_html) if front_html else ""

    id_to_file: dict[str, str] = {}
    if title_id:
        id_to_file[title_id] = "titlepage.xhtml"
    for ident in re.findall(r'id="([^"]+)"', front_html):
        id_to_file.setdefault(ident, "titlepage.xhtml")
    for i, ch in enumerate(chapters, start=1):
        ch["file"] = f"chapter{i:02d}.xhtml"
        for ident in re.findall(r'id="([^"]+)"', ch["html"]):
            id_to_file.setdefault(ident, ch["file"])

    broken: list[str] = []
    front_html, b = rewrite_anchors(front_html, id_to_file)
    broken += b
    for ch in chapters:
        ch["html"], b = rewrite_anchors(ch["html"], id_to_file)
        broken += b

    if not chapter_tokens:
        say("note: no chapters found; the whole document is on the title page")
    say(f"chapters={len(chapters)} diagrams={len(ctx.diagrams)} images={len(ctx.used)}")

    write_epub(out, work, oebps, text_dir, images, styles, meta, title, author,
               args.lang, front_html, chapters, title_id, broken)
    say(f"wrote {out} ({out.stat().st_size // 1024} KB)")

    ok = True
    if not args.no_verify:
        ok = verify(out, text_dir, tokens, title, author,
                    drop_first_h1=args.chapter_level != 1)
    if args.shots:
        shots(args.shots.resolve(), text_dir, chapters)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
