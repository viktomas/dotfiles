#!/usr/bin/env bash
# Run a one-shot subagent: no extensions, only shared skills.
#
# Usage: subagent.sh --slug <slug> [--model <family|id>] [--timeout <seconds>] "<prompt>"

set -euo pipefail

SESSION_DIR="$HOME/.pi/agent/subagent-sessions"
SHARED_SKILLS="$HOME/.pi/agent/skills-shared"
DEFAULT_MODEL="sonnet"
DEFAULT_TIMEOUT=600

slug=""
model="$DEFAULT_MODEL"
timeout_s="$DEFAULT_TIMEOUT"
prompt=""

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} --slug <slug> [--model <family|id>] [--timeout <seconds>] "<prompt>"

  --slug <slug>       short descriptive id, [a-z0-9-] only (e.g. lsp-auth)
  --model <family|id> model family (opus, sonnet, glm, …) or a full
                      model id (default: $DEFAULT_MODEL)
  --timeout <seconds> kill the run after this long (default: $DEFAULT_TIMEOUT)
  <prompt>            self-contained task; read from stdin when omitted
EOF
  exit "${1:-1}"
}

die() {
  echo "${0##*/}: $*" >&2
  exit 1
}

# --- arg parsing -------------------------------------------------------------
while (($#)); do
  case "$1" in
    --slug)
      [[ $# -ge 2 ]] || die "--slug requires a value"
      slug="$2"
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || die "--model requires a value"
      model="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout requires a value"
      timeout_s="$2"
      shift 2
      ;;
    -h | --help)
      usage 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z $prompt ]] || die "unexpected extra argument: $1"
      prompt="$1"
      shift
      ;;
  esac
done

# anything after `--` is the prompt
if (($#)); then
  [[ -z $prompt ]] || die "unexpected extra argument: $1"
  prompt="$1"
  shift
  (($#)) && die "unexpected extra argument: $1"
fi

# --- validation --------------------------------------------------------------
[[ -n $slug ]] || die "--slug is required"
[[ $slug =~ ^[a-z0-9-]+$ ]] || die "--slug must match [a-z0-9-]+ (got: $slug)"
[[ -n $model ]] || die "--model must not be empty"
[[ $timeout_s =~ ^[0-9]+$ && $timeout_s -gt 0 ]] || die "--timeout must be a positive integer (got: $timeout_s)"

if [[ -z $prompt && ! -t 0 ]]; then
  prompt="$(cat)"
fi
[[ -n $prompt ]] || die "prompt is required (argument or stdin)"

[[ -d $SHARED_SKILLS ]] || die "shared skills dir not found: $SHARED_SKILLS"
mkdir -p "$SESSION_DIR"

# Families (opus, sonnet, glm, …) resolve through the `pi-model` alias
# table in the dotfiles bin (~/bin), so the model ids live in one place. A full
# id passes through unchanged; if pi-model can't be found or doesn't know the
# name, the argument goes to pi as typed (pi's own fuzzy match).
PI_MODEL=$(command -v pi-model || echo "$HOME/bin/pi-model")
resolved=$("$PI_MODEL" "$model" 2>/dev/null) || resolved=""
[[ -n $resolved ]] && model=$resolved

# --- run ---------------------------------------------------------------------
rc=0
timeout "$timeout_s" pi -p \
  --session-dir "$SESSION_DIR" \
  --session-id "sub-$slug" \
  -n "subagent: $slug" \
  --model "$model" \
  -ne -ns \
  --skill "$SHARED_SKILLS" \
  -- "$prompt" || rc=$?

if ((rc)); then
  if ((rc == 124)); then
    echo "${0##*/}: timed out after ${timeout_s}s" >&2
  else
    echo "${0##*/}: pi exited with $rc" >&2
  fi
  session="$(ls -t "$SESSION_DIR"/*"sub-$slug".jsonl 2>/dev/null | head -1 || true)"
  [[ -n $session ]] && echo "${0##*/}: session: $session" >&2
fi

exit "$rc"
