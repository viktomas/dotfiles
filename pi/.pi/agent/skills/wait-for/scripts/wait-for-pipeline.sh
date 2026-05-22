#!/usr/bin/env bash
# Usage: wait-for-pipeline.sh [pipeline_id] [timeout_seconds] [poll_interval_seconds]
#
# Waits for a GitLab pipeline to complete. Returns early with an error
# as soon as any required (non-allow_failure) job fails, instead of
# waiting for the entire pipeline to finish.
#
# If pipeline_id is omitted, auto-detects the latest pipeline for the
# current git branch (via glab ci get).
#
# Requires: glab CLI (authenticated), jq
# Must be run from a git repo so glab can resolve :id.
#
# Exit codes:
#   0 - pipeline succeeded
#   1 - pipeline failed (or a required job failed early)
#   2 - usage/detection error
#   3 - timed out
#
# On failure (exit 1), outputs JSON to stdout with failed job metadata:
#   { "pipeline_id": 123, "status": "failed",
#     "failed_jobs": [{ "id": 456, "name": "rspec", "stage": "test",
#                       "web_url": "...", "runner": {...}, "failure_reason": "..." }] }
#
# Human-readable summary is printed to stderr.
#
# Examples:
#   wait-for-pipeline.sh                  # auto-detect from current branch
#   wait-for-pipeline.sh 1234567
#   wait-for-pipeline.sh 1234567 600 30
#   # Capture failed job metadata:
#   if ! result=$(wait-for-pipeline.sh 1234567); then echo "$result" | jq '.failed_jobs[].name'; fi

set -euo pipefail

# --- Resolve pipeline ID ---
# Pipeline IDs are large numbers (7+ digits). Small numbers are timeout values.
if [[ $# -ge 1 && "$1" =~ ^[0-9]{7,}$ ]]; then
  PIPELINE_ID="$1"
  shift
else
  # Auto-detect latest pipeline for current branch
  BRANCH=$(git branch --show-current 2>/dev/null || true)
  if [[ -z "$BRANCH" ]]; then
    echo "Error: not on a branch and no pipeline_id provided." >&2
    exit 2
  fi

  CI_JSON=$(glab ci get -F json 2>/dev/null || true)
  PIPELINE_ID=$(echo "$CI_JSON" | jq -r '.id // empty')
  if [[ -z "$PIPELINE_ID" ]]; then
    echo "Error: no pipeline found for branch '$BRANCH'." >&2
    exit 2
  fi

  CREATED_AT=$(echo "$CI_JSON" | jq -r '.created_at // empty')
  PIPELINE_STATUS=$(echo "$CI_JSON" | jq -r '.status // "unknown"')
  WEB_URL=$(echo "$CI_JSON" | jq -r '.web_url // empty')

  # Compute age
  if [[ -n "$CREATED_AT" ]]; then
    CREATED_TS=$(date -jf "%Y-%m-%dT%H:%M:%S" "${CREATED_AT%%.*}" +%s 2>/dev/null \
      || date -d "${CREATED_AT}" +%s 2>/dev/null || echo "")
    if [[ -n "$CREATED_TS" ]]; then
      AGE_S=$(( $(date +%s) - CREATED_TS ))
      if [[ $AGE_S -ge 3600 ]]; then
        AGE_STR="$((AGE_S / 3600))h $((AGE_S % 3600 / 60))m ago"
      elif [[ $AGE_S -ge 60 ]]; then
        AGE_STR="$((AGE_S / 60))m $((AGE_S % 60))s ago"
      else
        AGE_STR="${AGE_S}s ago"
      fi
    else
      AGE_STR="at $CREATED_AT"
    fi
  else
    AGE_STR="unknown"
  fi

  echo "Detected latest pipeline for branch $BRANCH" >&2
  echo "Pipeline ID: $PIPELINE_ID, status: $PIPELINE_STATUS, triggered: $AGE_STR" >&2
  [[ -n "$WEB_URL" ]] && echo "URL: $WEB_URL" >&2
fi

TIMEOUT="${1:-600}"
INTERVAL="${2:-30}"

STARTED_AT=$(date +%s)
DEADLINE=$((STARTED_AT + TIMEOUT))

# Fetch failed required jobs and output JSON to stdout, summary to stderr.
# Args: $1=pipeline_status, $2=elapsed, $3=attempt, $4=message
fail_with_jobs() {
  local status="$1" elapsed="$2" attempt="$3" message="$4"

  echo "❌ $message" >&2

  JOBS_JSON=$(glab api "projects/:id/pipelines/$PIPELINE_ID/jobs?per_page=100" 2>/dev/null || true)
  FAILED_REQUIRED=$(echo "$JOBS_JSON" \
    | jq '[.[] | select(.status == "failed" and .allow_failure == false)
           | {id, name, stage, status, web_url, failure_reason,
              runner: {id: .runner.id, description: .runner.description, runner_type: .runner.runner_type},
              started_at, finished_at, duration}]')

  # Human-readable to stderr
  echo "" >&2
  echo "Failed jobs:" >&2
  echo "$FAILED_REQUIRED" | jq -r '.[] | "   • \(.name) (stage: \(.stage), id: \(.id))\n     reason: \(.failure_reason)\n     url: \(.web_url)"' >&2
  echo "" >&2
  echo "Inspect logs with:" >&2
  echo "$FAILED_REQUIRED" | jq -r '.[] | "   glab ci trace \(.id)"' >&2

  # Structured JSON to stdout
  jq -n --argjson pipeline_id "$PIPELINE_ID" \
        --arg status "$status" \
        --argjson failed_jobs "$FAILED_REQUIRED" \
    '{pipeline_id: $pipeline_id, status: $status, failed_jobs: $failed_jobs}'

  exit 1
}

echo "⏳ Waiting for pipeline $PIPELINE_ID (up to ${TIMEOUT}s, polling every ${INTERVAL}s)..." >&2

ATTEMPT=0
while true; do
  ATTEMPT=$((ATTEMPT + 1))
  NOW=$(date +%s)
  ELAPSED=$((NOW - STARTED_AT))

  # 1. Check pipeline status
  PIPELINE_JSON=$(glab api "projects/:id/pipelines/$PIPELINE_ID" 2>/dev/null || true)
  PIPELINE_STATUS=$(echo "$PIPELINE_JSON" | jq -r '.status // "unknown"')

  if [[ "$PIPELINE_STATUS" == "success" ]]; then
    echo "✅ Pipeline $PIPELINE_ID succeeded after ${ELAPSED}s (attempt #${ATTEMPT})" >&2
    exit 0
  fi

  if [[ "$PIPELINE_STATUS" == "failed" || "$PIPELINE_STATUS" == "canceled" ]]; then
    fail_with_jobs "$PIPELINE_STATUS" "$ELAPSED" "$ATTEMPT" \
      "Pipeline $PIPELINE_ID $PIPELINE_STATUS after ${ELAPSED}s (attempt #${ATTEMPT})"
  fi

  # 2. Pipeline still running — check for early job failures
  if [[ "$PIPELINE_STATUS" == "running" || "$PIPELINE_STATUS" == "pending" ]]; then
    JOBS_JSON=$(glab api "projects/:id/pipelines/$PIPELINE_ID/jobs?per_page=100" 2>/dev/null || true)
    FAILED_COUNT=$(echo "$JOBS_JSON" | jq '[.[] | select(.status == "failed" and .allow_failure == false)] | length')

    if [[ "$FAILED_COUNT" -gt 0 ]]; then
      fail_with_jobs "$PIPELINE_STATUS" "$ELAPSED" "$ATTEMPT" \
        "Pipeline $PIPELINE_ID has $FAILED_COUNT failed required job(s) after ${ELAPSED}s — pipeline is still $PIPELINE_STATUS but will inevitably fail."
    fi
  fi

  # 3. Timeout check
  if [[ $NOW -ge $DEADLINE ]]; then
    echo "⏰ Timed out after ${TIMEOUT}s (${ATTEMPT} attempts). Pipeline status: $PIPELINE_STATUS" >&2
    exit 3
  fi

  REMAINING=$((DEADLINE - NOW))
  SLEEP=$INTERVAL
  if [[ $REMAINING -lt $INTERVAL ]]; then
    SLEEP=$REMAINING
  fi

  printf "   [%3ds/%ds] attempt #%d — pipeline %s, sleeping %ds...\n" "$ELAPSED" "$TIMEOUT" "$ATTEMPT" "$PIPELINE_STATUS" "$SLEEP" >&2
  sleep "$SLEEP"
done
