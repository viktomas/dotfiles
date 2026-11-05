#!/usr/bin/env bash
# post-comment.sh — Post a review comment on an MR.
#
# With glab:  positioned inline diff comments (file + line)
# Without glab: prints the comment for the caller to post via DWS create_merge_request_note
#
# Usage:
#   post-comment.sh [--mr <IID>] --message <text>
#   post-comment.sh [--mr <IID>] --file <path> --line <N[:M]> --message <text>
#   post-comment.sh [--mr <IID>] --file <path> --old-line <N> --message <text>
#   post-comment.sh [--mr <IID>] --reply <discussion-id> --message <text>
#
# The :robot: AI-generated prefix is prepended automatically.
set -euo pipefail

MR_IID=""
FILE=""
LINE=""
OLD_LINE=""
REPLY_ID=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mr) MR_IID="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --line) LINE="$2"; shift 2 ;;
    --old-line) OLD_LINE="$2"; shift 2 ;;
    --reply) REPLY_ID="$2"; shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$MESSAGE" ]; then
  echo "error: --message is required" >&2
  exit 1
fi

# Prepend the AI-generated prefix
FULL_MESSAGE=":robot: AI-generated

$MESSAGE"

# ── Validate flag combinations ────────────────────────────────────────
if [ -n "$LINE" ] && [ -n "$OLD_LINE" ]; then
  echo "error: --line and --old-line cannot be used together" >&2
  exit 1
fi

if { [ -n "$LINE" ] || [ -n "$OLD_LINE" ]; } && [ -z "$FILE" ]; then
  echo "error: --line/--old-line require --file" >&2
  exit 1
fi

if [ -n "$REPLY_ID" ] && [ -n "$FILE" ]; then
  echo "error: --reply and --file are mutually exclusive" >&2
  exit 1
fi

# ── Check for glab ────────────────────────────────────────────────────
HAS_GLAB=false
if command -v glab >/dev/null 2>&1; then
  HAS_GLAB=true
fi

if [ "$HAS_GLAB" = true ]; then
  # ── Post with glab ──────────────────────────────────────────────────
  ARGS=()
  if [ -n "$MR_IID" ]; then
    ARGS+=("$MR_IID")
  fi

  if [ -n "$REPLY_ID" ]; then
    ARGS+=(--reply "$REPLY_ID")
  elif [ -n "$FILE" ]; then
    ARGS+=(--file "$FILE")
    if [ -n "$LINE" ]; then
      ARGS+=(--line "$LINE")
    elif [ -n "$OLD_LINE" ]; then
      ARGS+=(--old-line "$OLD_LINE")
    fi
  fi

  echo "$FULL_MESSAGE" | glab mr note create "${ARGS[@]}"
  echo "posted: true"
else
  # ── No glab — output for DWS tool ──────────────────────────────────
  echo "posted: false"
  echo "reason: glab not available"
  echo "action: use create_merge_request_note DWS tool"
  echo ""
  echo "=== COMMENT_PAYLOAD ==="

  if [ -n "$FILE" ]; then
    echo "type: diff"
    echo "file: $FILE"
    if [ -n "$LINE" ]; then
      echo "line: $LINE (new side)"
    elif [ -n "$OLD_LINE" ]; then
      echo "old_line: $OLD_LINE (old side)"
    fi
  elif [ -n "$REPLY_ID" ]; then
    echo "type: reply"
    echo "discussion_id: $REPLY_ID"
  else
    echo "type: general"
  fi

  echo ""
  echo "=== MESSAGE ==="
  echo "$FULL_MESSAGE"
fi
