#!/usr/bin/env bash
# Run a one-shot subagent: no extensions, only shared skills.
#
# Usage: subagent.sh --slug <slug> [--model <family|id>] [--timeout <seconds>]
#                    [--resume <sessionId>] "<prompt>"

set -euo pipefail

SESSION_DIR="$HOME/.pi/agent/subagent-sessions"
SHARED_SKILLS="$HOME/.agents/skills"
DEFAULT_MODEL="sonnet"
DEFAULT_TIMEOUT=600
# Fleet records (contract v1): runs/<runId>.json, see the task repo's DECISIONS.md.
FLEET_DIR="${TASK_FLEET_DIR:-$HOME/.pi/agent/fleet}"
FLEET_EXT="$HOME/.pi/agent/extensions/fleet.ts"

slug=""
model="$DEFAULT_MODEL"
timeout_s="$DEFAULT_TIMEOUT"
resume=""
prompt=""

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} --slug <slug> [--model <family|id>] [--timeout <seconds>] [--resume <sessionId>] "<prompt>"

  --slug <slug>       short descriptive id, [a-z0-9-] only (e.g. lsp-auth)
  --model <family|id> model family (opus, sonnet, glm, …) or a full
                      model id (default: $DEFAULT_MODEL)
  --timeout <seconds> kill the run after this long (default: $DEFAULT_TIMEOUT)
  --resume <id>       continue an earlier session (the id printed on the
                      "session:" stderr line, sub-<slug>-<epoch>); fails if
                      that session does not exist. Without it every run is new.
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
    --resume)
      [[ $# -ge 2 ]] || die "--resume requires a value"
      resume="$2"
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
[[ -z $resume || $resume =~ ^[A-Za-z0-9._-]+$ ]] || die "--resume takes a session id like sub-<slug>-<epoch> (got: $resume)"

if [[ -z $prompt && ! -t 0 ]]; then
  prompt="$(cat)"
fi
[[ -n $prompt ]] || die "prompt is required (argument or stdin)"

[[ -d $SHARED_SKILLS ]] || die "shared skills dir not found: $SHARED_SKILLS"
mkdir -p "$SESSION_DIR"

# --- session id ----------------------------------------------------------------
# Every run gets its own session (slug reuse used to silently append to an old
# transcript). Continuing one is deliberate: --resume <sessionId>.
epoch=$(date +%s)
if [[ -n $resume ]]; then
  resume_file="$(ls -t "$SESSION_DIR"/*_"$resume".jsonl 2>/dev/null | head -1 || true)"
  [[ -n $resume_file ]] || die "--resume: no session '$resume' in $SESSION_DIR"
  session_id="$resume"
else
  session_id="sub-$slug-$epoch"
fi

# Families (opus, sonnet, glm, …) resolve through the `pi-model` alias
# table in the dotfiles bin (~/bin), so the model ids live in one place. A full
# id passes through unchanged; if pi-model can't be found or doesn't know the
# name, the argument goes to pi as typed (pi's own fuzzy match).
PI_MODEL=$(command -v pi-model || echo "$HOME/bin/pi-model")
model_in="$model"
resolved=$("$PI_MODEL" "$model" 2>/dev/null) || resolved=""
[[ -n $resolved ]] && model=$resolved

# --- goal (one line, derived with a cheap model) ---------------------------------
# Synchronous (~1-1.5s). Never fails the run: any problem falls back to the
# first non-empty prompt line. FLEET_GOAL_MODEL="" skips the model call.
derive_goal() {
  local g="" gm="${FLEET_GOAL_MODEL-haiku}" gid
  if [[ -n $gm ]]; then
    gid=$("$PI_MODEL" "$gm" 2>/dev/null) || gid=""
    [[ -n $gid ]] || gid="$gm"
    g=$(printf %s "$prompt" | head -c 8000 | timeout 10 pi -p --no-session -ne -ns -np -nc -nt \
      --no-themes --thinking off --model "$gid" \
      "The piped text is a task given to an AI agent. Reply with ONE line (at most 100 characters) summarizing what the agent is asked to do. Do not do the task and do not answer it; output only the summary line." \
      2>/dev/null) || g=""
    # first line only, taken after pi has exited (awk quitting early would EPIPE pi)
    g=$(printf '%s\n' "$g" | awk 'NF {print; exit}') || g=""
  fi
  if [[ -z ${g//[[:space:]]/} ]]; then
    g=$(printf '%s\n' "$prompt" | awk 'NF {print; exit}') || g=""
  fi
  g="${g#"${g%%[![:space:]]*}"}"
  g="${g%"${g##*[![:space:]]}"}"
  printf '%s' "${g:0:100}"
}
goal="$(derive_goal || true)"

# --- fleet registration --------------------------------------------------------
# runs/<runId>.json is written now and rewritten on exit with endedAt/rc/timedOut
# (never deleted; pruned after 7 days). A SIGKILLed script never gets to rewrite
# it: readers derive "killed" from a missing endedAt + dead scriptPid.
# All fleet writes are best-effort; they never fail the run.
runid="$slug-$epoch-$$"
RUN_FILE="$FLEET_DIR/runs/$runid.json"
deadline_iso=""
fleet_write() {
  # $1 = jq filter applied on top of the current record
  local tmp="$RUN_FILE.tmp"
  { jq "$1" "$RUN_FILE" >"$tmp" && mv "$tmp" "$RUN_FILE"; } 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
}
{
  mkdir -p "$FLEET_DIR/runs"
  find "$FLEET_DIR/runs" -maxdepth 1 -name '*.json' -mtime +7 -delete 2>/dev/null || true
  pane=""
  [[ -n ${ZELLIJ_PANE_ID:-} ]] && pane="terminal_$ZELLIJ_PANE_ID"
  jq -n \
    --arg runId "$runid" --arg slug "$slug" --arg model "$model" --arg goal "$goal" \
    --arg cwd "$PWD" --arg sessionId "$session_id" \
    --argjson epoch "$(date +%s)" --argjson timeoutS "$timeout_s" --argjson pid "$$" \
    --argjson resumed "$([[ -n $resume ]] && echo true || echo false)" \
    --arg task "${TASK_ID:-}" --arg psession "${PI_SESSION_ID:-}" \
    --arg psfile "${PI_SESSION_FILE:-}" --arg zsession "${ZELLIJ_SESSION_NAME:-}" \
    --arg pane "$pane" --arg prunId "${FLEET_RUN_ID:-}" \
    '{v: 1, runId: $runId, kind: "pi-sub", slug: $slug, model: $model, goal: $goal,
      cwd: $cwd, sessionId: $sessionId, startedAt: ($epoch | todate), timeoutS: $timeoutS,
      deadline: ($epoch + $timeoutS | todate), scriptPid: $pid, resumed: $resumed,
      parent: {task: $task, session: $psession, sessionFile: $psfile,
               zellijSession: $zsession, pane: $pane, runId: $prunId}}' \
    >"$RUN_FILE.tmp" && mv "$RUN_FILE.tmp" "$RUN_FILE"
  deadline_iso="$(jq -r .deadline "$RUN_FILE")"
} 2>/dev/null || true

# Legacy registry for work/scripts/fleet.sh (until it is retired): the file is
# present only while the run is alive.
ACTIVE_DIR="$SESSION_DIR/active"
mkdir -p "$ACTIVE_DIR"
ACTIVE_FILE="$ACTIVE_DIR/$$.json"
jq -n \
  --arg slug "$slug" \
  --arg model "$model_in" \
  --arg parentTask "${TASK_ID:-}" \
  --arg goal "$prompt" \
  --arg pid "$$" \
  --argjson startedAt "$epoch" \
  '{slug: $slug, model: $model, parentTask: $parentTask,
    goal: ($goal | .[0:400]), startedAt: $startedAt, pid: ($pid | tonumber)}' \
  > "$ACTIVE_FILE"

finish() { # $1 = exit status of the script
  local ec="$1"
  rm -f "$ACTIVE_FILE"
  [[ -f $RUN_FILE ]] || return 0
  fleet_write "$(printf '. + {endedAt: (now | floor | todate), rc: %d, timedOut: (%d == 124 or %d == 137)}' "$ec" "$ec" "$ec")"
}
trap 'ec=$?; finish "$ec" || true; exit "$ec"' EXIT

export FLEET_RUN_ID="$runid"
export FLEET_PARENT_SESSION="${PI_SESSION_ID:-}"
export FLEET_DEADLINE="$deadline_iso"

ext=()
[[ -f $FLEET_EXT ]] && ext=(-e "$FLEET_EXT")

# --- run ---------------------------------------------------------------------
# pi warns "No project session found with id …; creating a new session" for
# every fresh unique id; that one line is filtered, the rest of stderr passes.
rc=0
timeout -k 30 "$timeout_s" pi -p \
  --session-dir "$SESSION_DIR" \
  --session-id "$session_id" \
  -n "subagent: $slug" \
  --model "$model" \
  -ne -ns \
  ${ext[@]+"${ext[@]}"} \
  --skill "$SHARED_SKILLS" \
  -- "$prompt" 2> >(grep --line-buffered -v 'No project session found' >&2 || true) || rc=$?
# let the stderr filter flush before our own lines ($! may be unset)
# Bounded: a background process the agent left behind may hold stderr open.
fpid="${!:-}"
if [[ -n $fpid ]]; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$fpid" 2>/dev/null || break; sleep 0.1; done
fi

if ((rc)); then
  if ((rc == 124)); then
    echo "${0##*/}: timed out after ${timeout_s}s" >&2
  else
    echo "${0##*/}: pi exited with $rc" >&2
  fi
fi
session_file="$(ls -t "$SESSION_DIR"/*_"$session_id".jsonl 2>/dev/null | head -1 || true)"
echo "${0##*/}: session: $session_id${session_file:+ ($session_file)}" >&2

exit "$rc"
