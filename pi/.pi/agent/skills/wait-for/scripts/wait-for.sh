#!/usr/bin/env bash
# Usage: wait-for.sh <command> [timeout_seconds] [poll_interval_seconds]
#
# Runs <command> repeatedly until it exits 0 or timeout is reached.
# Exit codes:
#   0 - command succeeded
#   1 - timed out
#   2 - usage error
#
# Examples:
#   wait-for.sh "glab mr view 123 -R gitlab-org/cli -F json | jq -e '.state == \"merged\"'" 300
#   wait-for.sh "curl -sf https://example.com/health" 60 5
#   wait-for.sh "test -f /tmp/done.flag" 120

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: wait-for.sh <command> [timeout_seconds] [poll_interval_seconds]" >&2
  exit 2
fi

CMD="$1"
TIMEOUT="${2:-300}"
INTERVAL="${3:-10}"

STARTED_AT=$(date +%s)
DEADLINE=$((STARTED_AT + TIMEOUT))

echo "⏳ Waiting up to ${TIMEOUT}s (polling every ${INTERVAL}s)..."
echo "   Command: $CMD"

ATTEMPT=0
while true; do
  ATTEMPT=$((ATTEMPT + 1))
  NOW=$(date +%s)
  ELAPSED=$((NOW - STARTED_AT))

  if eval "$CMD" >/dev/null 2>&1; then
    echo "✅ Condition met after ${ELAPSED}s (attempt #${ATTEMPT})"
    exit 0
  fi

  if [[ $NOW -ge $DEADLINE ]]; then
    echo "❌ Timed out after ${TIMEOUT}s (${ATTEMPT} attempts)"
    exit 1
  fi

  REMAINING=$((DEADLINE - NOW))
  SLEEP=$INTERVAL
  if [[ $REMAINING -lt $INTERVAL ]]; then
    SLEEP=$REMAINING
  fi

  printf "   [%3ds/%ds] attempt #%d — not yet, sleeping %ds...\n" "$ELAPSED" "$TIMEOUT" "$ATTEMPT" "$SLEEP"
  sleep "$SLEEP"
done
