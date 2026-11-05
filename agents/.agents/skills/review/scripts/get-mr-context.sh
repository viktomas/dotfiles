#!/usr/bin/env bash
# get-mr-context.sh — Gather MR metadata, branch state, and diffs.
#
# With glab:  full metadata (JSON) + diffs from remote or local
# Without glab: branch state only; instructs caller to use DWS tools
#
# Usage:
#   get-mr-context.sh [--mr <IID>] [--diff-source local|remote]
#
# When the branch is dirty and --diff-source is not explicitly set,
# the DIFFS section is skipped so the caller can ask the user first.
#
# Output sections are separated by markers for easy parsing.
set -euo pipefail

MR_IID=""
DIFF_SOURCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mr) MR_IID="$2"; shift 2 ;;
    --diff-source) DIFF_SOURCE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DIFF_SOURCE_EXPLICIT=true
if [ -z "$DIFF_SOURCE" ]; then
  DIFF_SOURCE="remote"
  DIFF_SOURCE_EXPLICIT=false
fi

HAS_GLAB=false
if command -v glab >/dev/null 2>&1; then
  HAS_GLAB=true
fi

# ── Section: tools available ──────────────────────────────────────────
echo "=== TOOLS ==="
echo "glab: $HAS_GLAB"

# ── Section: branch state ────────────────────────────────────────────
echo ""
echo "=== BRANCH_STATE ==="

BRANCH_STATUS="CLEAN"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ]; then
  BRANCH_STATUS="DETACHED_HEAD"
  echo "status: $BRANCH_STATUS"
  echo "branch: (detached)"
else
  echo "branch: $CURRENT_BRANCH"

  # We need the source branch name to compare. If we have glab + MR IID, get it.
  # Otherwise assume current branch is the source branch.
  SOURCE_BRANCH="$CURRENT_BRANCH"

  if [ "$CURRENT_BRANCH" != "$SOURCE_BRANCH" ]; then
    BRANCH_STATUS="NOT_CHECKED_OUT"
    echo "status: $BRANCH_STATUS"
    echo "source_branch: $SOURCE_BRANCH"
  else
    # Fetch latest remote state
    git fetch origin "$SOURCE_BRANCH" --quiet 2>/dev/null || true

    LOCAL_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    if git rev-parse --verify "origin/$SOURCE_BRANCH" >/dev/null 2>&1; then
      REMOTE_HEAD=$(git rev-parse "origin/$SOURCE_BRANCH")
    else
      REMOTE_HEAD="not_on_remote"
    fi
    UNCOMMITTED=$(git status --porcelain 2>/dev/null || echo "")

    LOCAL_SHORT="${LOCAL_HEAD:0:8}"
    if [ "$REMOTE_HEAD" = "not_on_remote" ]; then
      REMOTE_SHORT="not_on_remote"
    else
      REMOTE_SHORT="${REMOTE_HEAD:0:8}"
    fi

    if [ "$LOCAL_HEAD" != "$REMOTE_HEAD" ] && [ -n "$UNCOMMITTED" ]; then
      BRANCH_STATUS="DIVERGED_AND_DIRTY"
    elif [ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]; then
      BRANCH_STATUS="UNPUSHED_COMMITS"
    elif [ -n "$UNCOMMITTED" ]; then
      BRANCH_STATUS="UNCOMMITTED_CHANGES"
    fi

    echo "status: $BRANCH_STATUS"
    echo "local_head: $LOCAL_SHORT"
    echo "remote_head: $REMOTE_SHORT"
    if [ -n "$UNCOMMITTED" ]; then
      echo "uncommitted:"
      echo "$UNCOMMITTED"
    fi
  fi
fi

# ── Section: MR metadata ─────────────────────────────────────────────
echo ""
echo "=== MR_METADATA ==="

if [ "$HAS_GLAB" = true ]; then
  MR_ARGS=()
  if [ -n "$MR_IID" ]; then
    MR_ARGS+=("$MR_IID")
  fi

  # Get MR metadata as JSON
  if MR_JSON=$(glab mr view "${MR_ARGS[@]}" -F json 2>/dev/null); then
    echo "$MR_JSON"
  else
    echo "error: failed to get MR metadata via glab"
    echo "hint: use get_merge_request DWS tool instead"
  fi
else
  echo "glab_missing: true"
  echo "hint: use get_merge_request DWS tool to fetch MR metadata"
  if [ -n "$MR_IID" ]; then
    echo "mr_iid: $MR_IID"
  fi
fi

# ── Section: review instructions ──────────────────────────────────────
echo ""
echo "=== REVIEW_INSTRUCTIONS ==="

if [ -f .gitlab/duo/mr-review-instructions.yaml ]; then
  cat .gitlab/duo/mr-review-instructions.yaml
else
  echo "none"
fi

# ── Section: diffs ────────────────────────────────────────────────────
echo ""
echo "=== DIFFS ==="

# If the branch is dirty and the user hasn't explicitly chosen a diff source,
# skip diffs so the caller can present the choice to the user first.
IS_DIRTY=false
case "$BRANCH_STATUS" in
  UNPUSHED_COMMITS|UNCOMMITTED_CHANGES|DIVERGED_AND_DIRTY) IS_DIRTY=true ;;
esac

if [ "$IS_DIRTY" = true ] && [ "$DIFF_SOURCE_EXPLICIT" = false ]; then
  echo "skipped: true"
  echo "reason: branch is dirty — ask the user whether to review remote or local diff"
  echo "hint: re-run with --diff-source local or --diff-source remote"
  exit 0
fi

if [ "$DIFF_SOURCE" = "local" ]; then
  # Local diff — need to figure out the target branch
  if [ "$HAS_GLAB" = true ]; then
    MR_ARGS=()
    if [ -n "$MR_IID" ]; then
      MR_ARGS+=("$MR_IID")
    fi
    TARGET_BRANCH=$(glab mr view "${MR_ARGS[@]}" -F json 2>/dev/null | grep -o '"target_branch":"[^"]*"' | head -1 | cut -d'"' -f4)
  fi

  if [ -z "${TARGET_BRANCH:-}" ]; then
    # Fallback: assume main or master
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
      TARGET_BRANCH="main"
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
      TARGET_BRANCH="master"
    else
      echo "error: cannot determine target branch for local diff"
      echo "hint: use --mr <IID> with glab, or use remote diff instead"
      exit 1
    fi
  fi

  echo "source: local"
  echo "target_branch: $TARGET_BRANCH"
  echo "---"
  git diff "origin/$TARGET_BRANCH"...HEAD -- . \
    ':!*.lock' ':!vendor/' ':!node_modules/' ':!*.min.js' ':!*.min.css' \
    ':!package-lock.json' ':!yarn.lock' ':!bun.lockb' ':!pnpm-lock.yaml'
else
  # Remote diff
  if [ "$HAS_GLAB" = true ]; then
    MR_ARGS=()
    if [ -n "$MR_IID" ]; then
      MR_ARGS+=("$MR_IID")
    fi
    echo "source: remote (glab)"
    echo "---"
    glab mr diff "${MR_ARGS[@]}" 2>/dev/null || {
      echo "error: glab mr diff failed"
      echo "hint: use list_merge_request_diffs DWS tool instead"
    }
  else
    echo "source: remote (no glab)"
    echo "hint: use list_merge_request_diffs DWS tool to fetch diffs"
    if [ -n "$MR_IID" ]; then
      echo "mr_iid: $MR_IID"
    fi
  fi
fi
