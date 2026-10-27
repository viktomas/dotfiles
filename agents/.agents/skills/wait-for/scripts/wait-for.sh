#!/usr/bin/env bash
# Usage: wait-for.sh "<command>" [--timeout N] [--interval N] [--fail-code N]
#
# Runs the command (a single quoted string, evaluated by the shell) repeatedly
# until it exits 0 (succeeded), returns the fail code (failed early), or the
# timeout is reached.
#
# Options:
#   --timeout N    max wait in seconds (default 300)
#   --interval N   sleep between attempts in seconds (default 10)
#   --fail-code N  exit code meaning "failed": stop and return it (stderr shown)
#
# Exit codes:
#   0  - command succeeded
#   1  - timed out
#   64 - usage error (bad arguments)
#   N  - the command returned the configured --fail-code, propagated as-is
#
# Examples:
#   wait-for.sh "test -f /tmp/done.flag" --timeout 120 --interval 5
#   wait-for.sh "./pipeline-succeeded.sh 123" --timeout 600 --interval 30 --fail-code 2

set -euo pipefail

usage() {
  echo "Usage: wait-for.sh \"<command>\" [--timeout N] [--interval N] [--fail-code N]" >&2
}

if [[ $# -lt 1 ]]; then
  usage; exit 64
fi
case "$1" in -h|--help) usage; exit 0 ;; esac

CMD="$1"
shift
TIMEOUT=300
INTERVAL=10
FAIL_CODE=""

# Read a flag value that may be given as "--flag value" or "--flag=value".
# Sets REPLY and SHIFTED (how many args to consume). Errors on a missing value.
take_value() {
  if [[ "$1" == *=* ]]; then
    REPLY="${1#*=}"; SHIFTED=1
  elif [[ $# -ge 2 ]]; then
    REPLY="$2"; SHIFTED=2
  else
    echo "Missing value for ${1%%=*}" >&2; exit 64
  fi
}

is_number() { [[ "$1" =~ ^[0-9]+$ ]] || { echo "Expected a number, got: $1" >&2; exit 64; }; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout|--timeout=*)       take_value "$@"; is_number "$REPLY"; TIMEOUT="$REPLY";    shift "$SHIFTED" ;;
    --interval|--interval=*)     take_value "$@"; is_number "$REPLY"; INTERVAL="$REPLY";   shift "$SHIFTED" ;;
    --fail-code|--fail-code=*)   take_value "$@"; is_number "$REPLY"; FAIL_CODE="$REPLY";   shift "$SHIFTED" ;;
    -h|--help)                   usage; exit 0 ;;
    *)                           echo "Unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

STARTED_AT=$(date +%s)
DEADLINE=$((STARTED_AT + TIMEOUT))

echo "⏳ Waiting up to ${TIMEOUT}s (polling every ${INTERVAL}s)..."
echo "   Command: $CMD"

ATTEMPT=0
while true; do
  ATTEMPT=$((ATTEMPT + 1))
  NOW=$(date +%s)
  ELAPSED=$((NOW - STARTED_AT))

  RC=0
  ERR=$(eval "$CMD" 2>&1 >/dev/null) || RC=$?

  if [[ $RC -eq 0 ]]; then
    echo "✅ Condition met after ${ELAPSED}s (attempt #${ATTEMPT})"
    exit 0
  fi

  if [[ -n "$FAIL_CODE" && "$RC" -eq "$FAIL_CODE" ]]; then
    echo "🛑 Failed after ${ELAPSED}s (attempt #${ATTEMPT}) — command returned $RC"
    [[ -n "$ERR" ]] && echo "$ERR" >&2
    exit "$RC"
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
