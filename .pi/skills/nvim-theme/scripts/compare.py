#!/usr/bin/env python3
"""Render the same file under several theme variations and build a comparison page.

    compare.py FILE [options] LABEL[=lua-file] ...

Each positional argument is one option. The lua file is sourced after the buffer
loads (same hook `capture.sh` takes), so an option is "whatever this lua does to
the live theme" -- no config edit, no restart. A bare LABEL with no `=` is the
untouched theme and becomes the A/B reference.

    compare.py src/foo.ts \
        "current" \
        "green C*10=/tmp/green10.lua" \
        "mauve C*10=/tmp/mauve10.lua" \
        --out /tmp/strings.html --open

Every option is captured in *both* variants (THEME.md's rule), decoded, and
emitted as SVG -- the page is the real painted pixels, not a mockup. Hovering a
screenshot flips it back to the reference, which is the only way to judge a
change this small.

The per-card readout is computed, not declared: each option's palette is diffed
against the reference's, so the page tells you which colours the change actually
introduced, what share of the window they cover and their dE from base.
"""

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
VARIANTS = ("dark", "light")


# --------------------------------------------------------------------------
# capture + decode
# --------------------------------------------------------------------------

def tiers_for(variant, workdir, refresh=False):
    out = workdir / f"tiers-{variant}.json"
    if refresh or not out.exists():
        res = subprocess.run([str(HERE / "tiers.sh"), variant],
                             capture_output=True, text=True)
        if res.returncode != 0 or not res.stdout.strip():
            sys.exit(f"tiers.sh {variant} failed:\n{res.stderr}")
        out.write_text(res.stdout)
    return json.loads(out.read_text())


SGR = re.compile(r"\x1b\[[0-9;:]*m")


def painted_rows(dump):
    """Screen rows that actually have text on them, escapes stripped."""
    return sum(1 for line in dump.splitlines() if SGR.sub("", line).strip())


def capture(opt_id, lua, variant, args, workdir):
    """Run the real nvim once and return the pane dump path.

    Retries on a half-drawn pane. Under parallel load nvim and the LSP are both
    slower than the fixed `CAPTURE_WAIT`, and a short wait fails *silently*: the
    dump is simply shorter, which decodes into a plausible-looking page with a
    few colours in it. Every such capture is a lie, so detect and redo it.
    """
    pane = workdir / f"{opt_id}-{variant}.pane"
    # Pin the variant explicitly even for dark: the terminal may have set the
    # other one, and a capture must never depend on ambient state.
    prelude = f'require("user.theme").set_variant("{variant}")\n'
    body = Path(lua).read_text() if lua else 'require("user.theme").apply()\n'
    combined = workdir / f"{opt_id}-{variant}.lua"
    combined.write_text(prelude + body)

    want = max(4, int(args.rows_tall * 0.6))
    # Reusing a good pane is what makes iterating on the *page* cheap: the
    # captures cost ~20s each, the HTML costs nothing.
    if pane.exists() and not args.refresh and painted_rows(pane.read_text()) >= want:
        return pane
    wait = args.wait
    for attempt in range(3):
        env = dict(os.environ,
                   CAPTURE_WAIT=str(wait),
                   CAPTURE_COLS=str(args.cols),
                   CAPTURE_ROWS=str(args.rows_tall))
        res = subprocess.run(
            [str(HERE / "capture.sh"), args.file, str(args.line), str(combined)],
            capture_output=True, text=True, env=env, cwd=args.cwd)
        if res.returncode != 0:
            sys.exit(f"capture failed for {opt_id}/{variant}:\n{res.stderr}")
        if painted_rows(res.stdout) >= want:
            pane.write_text(res.stdout)
            return pane
        wait = int(wait * 1.6)
        print(f"  ! {opt_id}/{variant} drew only {painted_rows(res.stdout)}/{want} rows,"
              f" retrying with {wait}s", file=sys.stderr)
    sys.exit(f"capture for {opt_id}/{variant} never drew -- raise --wait")


def decode(pane, variant, args, workdir, tiers_path, bg):
    """Return (svg-markup, palette rows) for one capture."""
    stem = pane.with_suffix("")
    svg = Path(f"{stem}.svg")
    base = [sys.executable, str(HERE / "decode.py"), str(pane),
            "--tiers", str(tiers_path), "--bg", bg]
    subprocess.run(base + ["--rows", args.rows, "--svg", str(svg)],
                   capture_output=True, text=True, check=True)
    summary = subprocess.run(base + ["--summary"],
                             capture_output=True, text=True, check=True).stdout

    rows = []
    for line in summary.splitlines()[1:]:
        m = re.match(r"\s*(#[0-9a-f]{6})\s+(\S+)\s+([\d.]+)%\s+([\d.]+)\s+(\S+)", line)
        if m:
            colour, attrs, share, de, tier = m.groups()
            rows.append({"colour": colour, "attrs": "" if attrs == "-" else attrs,
                         "share": float(share), "de": float(de),
                         "tier": "" if tier == "?" else tier})

    markup = svg.read_text()
    # Let the page size it; keep the aspect ratio from the viewBox.
    markup = markup.replace("<svg ", '<svg preserveAspectRatio="xMinYMin meet" ', 1)
    markup = re.sub(r'\swidth="\d+"\s+height="\d+"', "", markup, count=1)
    return markup, rows


def diff_palette(rows, ref_rows):
    """Colours this option has that the reference does not, biggest share first."""
    ref = {(r["colour"], r["attrs"]) for r in ref_rows}
    new = [r for r in rows if (r["colour"], r["attrs"]) not in ref]
    return sorted(new, key=lambda r: -r["share"])


# --------------------------------------------------------------------------
# page
# --------------------------------------------------------------------------

CSS = """
:root { --bg:#14161a; --fg:#d7dade; --dim:#8b9098; --line:#2a2e35; }
body.light { --bg:#f6f6f4; --fg:#26282b; --dim:#6b6f75; --line:#dcdcd8; }
* { box-sizing:border-box }
body { margin:0; background:var(--bg); color:var(--fg);
  font:15px/1.55 ui-sans-serif,-apple-system,"Segoe UI",sans-serif }
header { padding:26px 32px 15px; border-bottom:1px solid var(--line);
  position:sticky; top:0; background:var(--bg); z-index:5 }
h1 { margin:0 0 4px; font-size:19px; font-weight:600; letter-spacing:-.01em }
.sub { color:var(--dim); font-size:12.5px; font-family:ui-monospace,Menlo,monospace }
.controls { margin-top:13px; display:flex; gap:18px; align-items:center;
  flex-wrap:wrap; font-size:13px }
.seg { display:inline-flex; border:1px solid var(--line); border-radius:7px; overflow:hidden }
.seg button { background:transparent; border:0; color:var(--dim); padding:5px 13px;
  font:inherit; cursor:pointer }
.seg button.sel { background:var(--line); color:var(--fg) }
.hint { color:var(--dim) }
kbd { border:1px solid var(--line); border-radius:4px; padding:1px 5px;
  font-family:ui-monospace,monospace; font-size:11px }
main { padding:26px 32px 60px; display:grid; gap:26px;
  grid-template-columns:repeat(auto-fit,minmax(var(--min,430px),1fr)); max-width:1900px }
body.solo main { grid-template-columns:1fr; max-width:1100px }
.card { margin:0 }
figcaption { display:flex; justify-content:space-between; align-items:baseline;
  gap:12px; margin-bottom:8px; flex-wrap:wrap }
.name { font-weight:600; font-size:14px }
.meta { color:var(--dim); font-size:12px; font-family:ui-monospace,Menlo,monospace }
.meta b { color:var(--fg); font-weight:600 }
.sw { display:inline-block; width:10px; height:10px; border-radius:2px;
  margin-right:5px; outline:1px solid rgba(128,128,128,.35) }
.shot { position:relative; border:1px solid var(--line); border-radius:9px;
  overflow:hidden; line-height:0 }
.shot svg { width:100%; height:auto; display:block }
.pane { display:none }
.pane.live:not(.ref) { display:block }
.shot.ab:hover .pane.live:not(.ref) { display:none }
.shot.ab:hover .pane.live.ref { display:block }
.badge { position:absolute; top:8px; right:10px; font:11px ui-monospace,monospace;
  color:var(--dim); background:color-mix(in srgb, var(--bg) 80%, transparent);
  padding:2px 7px; border-radius:5px; opacity:0; transition:.12s }
.shot.ab:hover .badge { opacity:1 }
table { border-collapse:collapse; margin:0 32px 50px; font-size:12.5px;
  font-family:ui-monospace,Menlo,monospace }
th,td { text-align:left; padding:6px 18px 6px 0; border-bottom:1px solid var(--line) }
th { color:var(--dim); font-weight:500 }
.note { margin:0 32px 24px; max-width:78ch; color:var(--dim); font-size:13.5px }
.note code { font-size:12.5px }
"""

JS = """
const DATA = __DATA__;
let variant = "dark";
function render() {
  document.body.classList.toggle("light", variant === "light");
  document.querySelectorAll(".card").forEach(card => {
    const id = card.dataset.opt;
    // Visibility is CSS's job (the hover A/B lives there); JS only marks which
    // variant is live, so `.live` + `:hover` stay composable.
    card.querySelectorAll(".pane").forEach(p => {
      p.classList.toggle("live", p.dataset.variant === variant);
    });
    card.querySelector(".meta").innerHTML = DATA[id][variant].meta;
  });
  document.querySelectorAll("tbody tr").forEach(tr => {
    tr.style.display = tr.dataset.variant === variant ? "" : "none";
  });
}
document.querySelectorAll("#variant button").forEach(b => b.onclick = () => {
  variant = b.dataset.v;
  document.querySelectorAll("#variant button").forEach(x => x.classList.toggle("sel", x === b));
  render();
});
addEventListener("keydown", e => {
  if (e.key === "v" || e.key === "V") {
    document.querySelector(`#variant button[data-v="${variant === "dark" ? "light" : "dark"}"]`).click();
  }
});
render();
"""


def meta_html(new_rows, is_ref):
    if is_ref:
        return "<i>A/B reference</i>"
    if not new_rows:
        return "<i>no palette change</i>"
    bits = []
    for r in new_rows[:3]:
        bits.append(
            f'<i class="sw" style="background:{r["colour"]}"></i>{r["colour"]}'
            f' · {r["share"]:.1f}% · ΔE <b>{r["de"]:.1f}</b>')
    if len(new_rows) > 3:
        bits.append(f"+{len(new_rows) - 3} more")
    return " &nbsp;·&nbsp; ".join(bits)


def build_page(args, opts, shots, palettes, refs):
    cards, data = [], {}
    for opt_id, label, lua in opts:
        is_ref = opt_id == opts[0][0]
        panes = []
        for v in VARIANTS:
            panes.append(f'<div class="pane" data-variant="{v}">{shots[(opt_id, v)]}</div>')
            if not is_ref:
                panes.append(f'<div class="pane ref" data-variant="{v}">'
                             f'{shots[(opts[0][0], v)]}</div>')
        data[opt_id] = {
            v: {"meta": meta_html(diff_palette(palettes[(opt_id, v)], refs[v]), is_ref)}
            for v in VARIANTS
        }
        cards.append(f"""<figure class="card" data-opt="{html.escape(opt_id)}">
  <figcaption><span class="name">{html.escape(label)}</span><span class="meta"></span></figcaption>
  <div class="shot{'' if is_ref else ' ab'}">{''.join(panes)}
    {'' if is_ref else '<div class="badge">reference</div>'}</div>
</figure>""")

    body_rows = []
    for v in VARIANTS:
        for opt_id, label, _ in opts:
            new = diff_palette(palettes[(opt_id, v)], refs[v])
            if not new:
                body_rows.append(f'<tr data-variant="{v}"><td>{html.escape(label)}</td>'
                                 f'<td colspan="4"><i>reference / unchanged</i></td></tr>')
            for r in new:
                body_rows.append(
                    f'<tr data-variant="{v}"><td>{html.escape(label)}</td>'
                    f'<td><i class="sw" style="background:{r["colour"]}"></i>{r["colour"]}</td>'
                    f'<td>{r["attrs"] or "—"}</td><td>{r["share"]:.1f}%</td><td>{r["de"]:.1f}</td></tr>')

    title = args.title or f"{Path(args.file).name} — theme options"
    sub = (f"{args.file} · line {args.line}, rows {args.rows} · real nvim, real LSP · "
           f"{len(opts)} options × {len(VARIANTS)} variants")
    solo = " solo" if len(opts) <= 2 else ""
    return f"""<!doctype html>
<meta charset="utf-8">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
<body class="{solo.strip()}">
<header>
  <h1>{html.escape(title)}</h1>
  <div class="sub">{html.escape(sub)}</div>
  <div class="controls">
    <span class="seg" id="variant">
      <button data-v="dark" class="sel">dark</button><button data-v="light">light</button></span>
    <span class="hint">hover a screenshot to flip back to the reference · <kbd>v</kbd> toggles variant</span>
  </div>
</header>
<main>
{chr(10).join(cards)}
</main>
{f'<p class="note">{args.note}</p>' if args.note else ''}
<table><thead><tr><th>option</th><th>colour introduced</th><th>attrs</th>
<th>share of window</th><th>ΔE vs base</th></tr></thead>
<tbody>{chr(10).join(body_rows)}</tbody></table>
<script>{JS.replace("__DATA__", json.dumps(data))}</script>
"""


# --------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("file", help="file to render (relative to --cwd)")
    p.add_argument("options", nargs="+", metavar="LABEL[=lua]",
                   help="first one is the A/B reference; bare LABEL = untouched theme")
    p.add_argument("--out", default="/tmp/theme-compare.html")
    p.add_argument("--cwd", default=os.getcwd(), help="run nvim here (for the LSP root)")
    p.add_argument("--line", type=int, default=1, help="first line shown")
    p.add_argument("--rows", default="1-32", help="screen rows to put in the SVG")
    p.add_argument("--cols", type=int, default=108)
    p.add_argument("--rows-tall", type=int, default=34, help="pane height")
    p.add_argument("--wait", type=int, default=22, help="seconds for the LSP to attach")
    p.add_argument("--jobs", type=int, default=3, help="parallel captures")
    p.add_argument("--title", default=None)
    p.add_argument("--note", default=None, help="paragraph under the grid (HTML ok)")
    p.add_argument("--keep", default=None,
                   help="work dir to keep captures in; reused on the next run")
    p.add_argument("--refresh", action="store_true",
                   help="re-capture even if --keep already has the panes")
    p.add_argument("--open", action="store_true")
    args = p.parse_args()

    opts = []
    for i, raw in enumerate(args.options):
        # Split on the LAST `=`, and only when the tail is a lua path -- labels
        # like `C*=10` contain `=` and must survive.
        label, sep, lua = raw.rpartition("=")
        if not sep or not lua.endswith(".lua"):
            label, lua = raw, None
        if lua and not Path(lua).exists():
            sys.exit(f"no such lua file: {lua}")
        opts.append((f"o{i}", label, lua or None))

    workdir = Path(args.keep) if args.keep else Path(tempfile.mkdtemp(prefix="theme-compare-"))
    workdir.mkdir(parents=True, exist_ok=True)

    tiers = {v: tiers_for(v, workdir, args.refresh) for v in VARIANTS}
    bg = {v: tiers[v]["__bg"]["fg"] for v in VARIANTS}

    jobs = [(o, v) for o in opts for v in VARIANTS]
    print(f"capturing {len(jobs)} panes ({args.wait}s each, {args.jobs} at a time)…",
          file=sys.stderr)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        panes = list(pool.map(
            lambda j: capture(j[0][0], j[0][2], j[1], args, workdir), jobs))

    shots, palettes = {}, {}
    for (opt, v), pane in zip(jobs, panes):
        markup, rows = decode(pane, v, args, workdir,
                              workdir / f"tiers-{v}.json", bg[v])
        shots[(opt[0], v)] = markup
        palettes[(opt[0], v)] = rows
        print(f"  {opt[1]:<28s} {v:<5s} {len(rows)} colours", file=sys.stderr)

    refs = {v: palettes[(opts[0][0], v)] for v in VARIANTS}
    Path(args.out).write_text(build_page(args, opts, shots, palettes, refs))
    print(f"\n{args.out}", file=sys.stderr)
    if args.keep:
        print(f"captures kept in {workdir}", file=sys.stderr)
    elif shutil.which("open"):
        pass
    if args.open and shutil.which("open"):
        subprocess.run(["open", args.out])


if __name__ == "__main__":
    main()
