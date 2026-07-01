#!/usr/bin/env bash
# Usage: pipeline-succeeded.sh [pipeline_id_or_url]
#
# One-shot check of a GitLab pipeline, meant to be polled by wait-for.sh.
# No argument -> latest pipeline for the current git branch.
# A URL argument -> its trailing number is used as the pipeline ID.
#
# Requires: glab (authenticated), jq. Run from inside the git repo.
#
# Exit codes:
#   0 - pipeline succeeded
#   1 - still running (keep waiting)
#   2 - terminal failure: pipeline failed/canceled or a required job failed
#       (prints the failed required jobs to stderr)

set -euo pipefail

ARG="${1:-}"
GET=(glab ci get -F json --with-job-details)
if [[ "$ARG" =~ ^https?:// ]]; then
  GET+=(-p "${ARG##*/}")
elif [[ "$ARG" =~ ^[0-9]+$ ]]; then
  GET+=(-p "$ARG")
fi

JSON=$("${GET[@]}" 2>/dev/null || true)
STATUS=$(echo "$JSON" | jq -r '.status // empty')

if [[ -z "$STATUS" ]]; then
  echo "Error: no pipeline found." >&2
  exit 2
fi

[[ "$STATUS" == "success" ]] && exit 0

FAILED=$(echo "$JSON" | jq -r '.jobs[]
  | select(.status=="failed" and .allow_failure==false)
  | "  • \(.name)  \(.web_url)"')

if [[ "$STATUS" == "failed" || "$STATUS" == "canceled" || -n "$FAILED" ]]; then
  echo "❌ Pipeline $STATUS; failed required jobs:" >&2
  [[ -n "$FAILED" ]] && echo "$FAILED" >&2
  exit 2
fi

exit 1
