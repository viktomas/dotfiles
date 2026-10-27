#!/usr/bin/env bash
# Smoke tests for the EPUB builder. Builds each fixture and fails on an
# epubcheck error/warning, a missing content word, or a broken structure.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FIX="$ROOT/tests/fixtures"
BUILD="$ROOT/scripts/build_epub.py"
PYTHON=${PYTHON:-python3}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/epub-tests.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

for tool in epubcheck d2 magick identify rsvg-convert; do
    command -v "$tool" >/dev/null || fail "$tool is required (brew install d2 imagemagick librsvg epubcheck)"
done

build() {
    name=$1
    log="$TMP/$name.log"
    echo "== $name"
    if ! "$PYTHON" "$BUILD" "$FIX/$name.md" -o "$TMP/$name.epub" \
            --work "$TMP/work-$name" >"$log" 2>&1; then
        cat "$log" >&2
        fail "$name build exited non-zero"
    fi
    grep -Eq 'epubcheck: Messages: 0 fatals / 0 errors / 0 warnings' "$log" \
        || { cat "$log" >&2; fail "$name has epubcheck errors"; }
    grep -Eq 'content: [0-9]+ words, all present in the book' "$log" \
        || { cat "$log" >&2; fail "$name lost content words"; }
    grep -E 'epubcheck:|content:' "$log" | sed 's/^/   /'
}

xhtml() { echo "$TMP/work-$1/OEBPS/text"; }

build t
if grep -Rq '<details' "$(xhtml t)"; then fail "t: <details> was not expanded"; fi
grep -q 'class="callout callout-note"' "$(xhtml t)"/chapter03.xhtml || fail "t: callout missing"
grep -q 'missing image: ' "$(xhtml t)"/chapter04.xhtml || fail "t: missing image text missing"

build u
grep -q '<h2 id="überblick">' "$(xhtml u)"/chapter02.xhtml || fail "u: unicode id lost"
[ "$(grep -c '<ul>' "$(xhtml u)"/chapter02.xhtml)" -ge 4 ] || fail "u: nested lists flattened"
grep -q '&gt; \[!NOTE\]' "$(xhtml u)"/chapter02.xhtml || fail "u: code fence was rewritten"
identify "$TMP/work-u/OEBPS/images/pic.jpg" | grep -q 'Gray' || fail "u: image not grayscaled"

build diff
d=$(xhtml diff)
grep -q 'class="callout callout-warning"' "$d"/chapter01.xhtml || fail "diff: warning callout missing"
grep -q 'class="callout callout-tip"' "$d"/chapter01.xhtml || fail "diff: tip callout missing"
grep -q 'Custom title' "$d"/chapter01.xhtml || fail "diff: custom callout title missing"
grep -q '<span class="add">' "$d"/chapter02.xhtml || fail "diff: added lines not styled"
grep -q '<span class="del">' "$d"/chapter02.xhtml || fail "diff: removed lines not styled"
grep -q 'class="details"' "$d"/chapter03.xhtml || fail "diff: details block missing"
grep -q 'class="summary"' "$d"/chapter03.xhtml || fail "diff: summary missing"
if grep -Rq 'language-svg' "$d"; then fail "diff: svg block rendered as code"; fi
grep -Rq 'chapter02.xhtml#diff' "$d" || fail "diff: internal anchor not rewritten"
if grep -q 'words missing' "$TMP/diff.log"; then fail "diff: content words unexpectedly missing"; fi

# Deliberate loss: build an EPUB, delete a sentence from it, and check that
# --check notices. This is the regression for the word comparison.
"$PYTHON" - "$TMP/diff.epub" "$TMP/loss.epub" <<'PY'
import sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename.startswith("OEBPS/text/") and item.filename.endswith(".xhtml"):
            data = data.replace(b"One warning, its own box.", b"")
        zout.writestr(item, data)
PY
if "$PYTHON" "$BUILD" "$TMP/loss.epub" --check --source "$FIX/diff.md" \
        >"$TMP/loss.log" 2>&1; then
    cat "$TMP/loss.log" >&2
    fail "loss check exited zero"
fi
grep -q 'words missing' "$TMP/loss.log" || { cat "$TMP/loss.log" >&2; fail "loss check did not report missing words"; }
echo "== deliberate loss"
grep -E 'words missing|content check' "$TMP/loss.log" | sed 's/^/   /'

echo "all epub smoke tests passed"
