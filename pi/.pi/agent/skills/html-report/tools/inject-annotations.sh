#!/usr/bin/env bash
# Inject the annotation system into an HTML report.
# Usage: inject-annotations.sh <report.html>
#
# Inserts the annotation CSS, HTML, and JS just before </body>.
# The report file is modified in-place. Safe to run multiple times
# (skips if annotations are already present).

set -euo pipefail

REPORT="${1:?Usage: inject-annotations.sh <report.html>}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAGMENT="${SKILL_DIR}/resources/annotations.html"

if [[ ! -f "$REPORT" ]]; then
  echo "Error: $REPORT not found" >&2
  exit 1
fi

if [[ ! -f "$FRAGMENT" ]]; then
  echo "Error: annotations fragment not found at $FRAGMENT" >&2
  exit 1
fi

# Idempotency: skip if already injected
if grep -q 'id="ann-panel"' "$REPORT" 2>/dev/null; then
  echo "Annotations already present in $REPORT — skipping"
  exit 0
fi

# Insert fragment just before </body>
# Use perl for reliable multi-line file insertion
perl -i -pe '
  BEGIN {
    local $/;
    open(my $fh, "<", "'"$FRAGMENT"'") or die "Cannot open fragment: $!";
    $fragment = <$fh>;
    close $fh;
  }
  if (/<\/body>/) {
    print $fragment . "\n";
  }
' "$REPORT"

echo "Annotations injected into $REPORT"
