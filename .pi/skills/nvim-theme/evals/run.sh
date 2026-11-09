#!/bin/sh
# Trigger-eval runner (agent-scaffolding phase 3). Runs every case in
# .pi/skills/<skill>/evals/triggers/ in an isolated pi session and reports
# which skills loaded, by scanning the new session log for SKILL.md reads.
#
# Isolation per ~/.agents/skills/agent-scaffolding/references/operational-gotchas.md:
#   - stdin closed (</dev/null) so batch runs don't swallow each other
#   - session identity stripped so cases don't write into the real task's
#     state or inherit the parent's model choice (env -u list below)
#   - the agent runs from this checkout, so repo + global skills are in scope
#     exactly as in a real session
#
# Usage: run.sh [skill] [case-id ...]   (no case ids = all cases)
#
# Cost: ~$0.02-0.08 per case; the trigger signal lands in the first 2-3
# turns, so cases are capped at CAP_S seconds.

set -eu

CAP_S=${CAP_S:-120}
SKILL=${1:-nvim-theme}
if [ $# -gt 0 ]; then shift; fi
only="$*"   # optional case-id filter, for iterating on a single case
repo=$(cd "$(dirname "$0")/../../../.." && pwd -P)
cases="$repo/.pi/skills/$SKILL/evals/triggers"
sessions="$HOME/.pi/agent/sessions"
slug="--$(printf '%s' "$repo" | sed 's|^/||; s|/|-|g')--"

pass=0; fail=0
for case in "$cases"/should*.md; do
  id=$(basename "$case" .md)
  case "$only" in "" | *"$id"*) ;; *) continue ;; esac
  want=$(printf '%s' "$id" | cut -d- -f1)   # should | shouldnot
  prompt=$(cat "$case")

  before=$(mktemp); after=$(mktemp)
  ls "$sessions/$slug" >"$before" 2>/dev/null || true
  # strip every session-identifying or model-picking variable the parent
  # session may carry (gotchas: inherited session identity)
  env -u TASK_ID -u TASK_DIR -u TASK_CATEGORIES -u PI_GARDENER \
      -u PI_SESSION_FILE -u PI_SESSION_ID -u PI_SESSION_TAG \
      -u PI_MODEL -u PI_PROVIDER -u PI_REASONING_LEVEL \
    timeout "$CAP_S" \
    pi -p "$prompt" </dev/null >/dev/null 2>&1 || true
  ls "$sessions/$slug" >"$after" 2>/dev/null || true
  new=$(comm -13 "$before" "$after" | head -1)
  rm -f "$before" "$after"
  if [ -z "$new" ] || [ ! -f "$sessions/$slug/$new" ]; then
    echo "??  $id  (no session log found - slug mismatch?)"; fail=$((fail+1)); continue
  fi
  log="$sessions/$slug/$new"
  # which skills were actually opened: read/edit tool calls on a SKILL.md
  # (the system prompt *lists* every skill's path, so a plain grep would
  # count all of them as loaded)
  loaded=$(python3 - "$log" <<'PY'
import json, re, sys
loaded = set()
rx = re.compile(r'skills/([a-zA-Z0-9_-]+)/SKILL\.md')
for line in open(sys.argv[1]):
    try:
        r = json.loads(line)
    except ValueError:
        continue
    m = r.get('message') or {}
    if m.get('role') != 'assistant':
        continue
    for c in m.get('content') or []:
        if c.get('type') != 'toolCall':
            continue
        if c.get('name') in ('read', 'write', 'edit'):
            hits = [str((c.get('arguments') or {}).get('path', ''))]
        elif c.get('name') == 'bash':
            # agents also open skills via cat/sed/head in bash - count those
            hits = [str((c.get('arguments') or {}).get('command', ''))]
        else:
            continue
        for h in hits:
            mm = rx.search(h)
            if mm:
                loaded.add(mm.group(1))
print(','.join(sorted(loaded)))
PY
)
  case ",$loaded," in
    *",$SKILL,"*) got=should ;;
    *) got=shouldnot ;;
  esac
  if [ "$got" = "$want" ]; then
    echo "ok  $id  loaded: ${loaded:-none} ($new)"; pass=$((pass+1))
  else
    echo "FAIL $id  wanted $want, got $got  loaded: ${loaded:-none} ($new)"; fail=$((fail+1))
  fi
done
echo "---"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
