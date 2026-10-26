#!/usr/bin/env bash
# Run one headless GitLab Duo CLI task, then audit it with a pi Sonnet checker.
#
# Usage: duo-subagent.sh --slug <slug> --cwd <worktree> [--model sonnet|opus|<duo id>]
#                        [--timeout <s>] [--idle <s>] [--resume <sessionId>]
#                        [--read-only] [--no-check] "<goal>"
#
# Duo's own exit code and `status` can't be trusted (lost stream tail and silent
# model fallback both exit 0; failed shell commands count as tool success), so
# this script works around each known gap:
#   - hard timeout + stderr idle watchdog (Duo has neither)
#   - kills the run early when Duo silently falls back to another model
#   - session id scraped from stderr when the run dies before writing JSON
#   - turn disposition read from the log (the exit code ignores it)
#   - deterministic prechecks: failed commands, loops, error elements, git state
#   - full transcript via `glab duo cli export` (incl. Duo subagents)
#   - user-level Duo subagents from ~/.pi/agent/duo-agents/*.md merged with the
#     repo's .agents/agents/*.md (Duo only reads the repo dir)
#   - --read-only: no headless plan mode, so the goal says so and the worktree
#     content is snapshotted before/after
#
# Prints the checker's prose, then ONE final JSON line (also <dir>/verdict.json):
#   {dir, sessionId, model, exitCode, readOnlyViolated, commits, verdict,
#    goalCompleted, suggestedAction, followupGoal, issues}
# Exit status: 0 = verdict PASS, 2 = any other verdict, 1 = usage error,
#              3 = the script itself crashed.

set -euo pipefail
trap 'echo "${0##*/}: crashed at line $LINENO" >&2; exit 3' ERR

RUNS_DIR="$HOME/.pi/agent/duo-runs"
USER_AGENTS_DIR="${DUO_AGENTS_DIR:-$HOME/.pi/agent/duo-agents}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBAGENT="$SCRIPT_DIR/subagent.sh"
CHECKER_PROMPT="$SCRIPT_DIR/duo-checker-prompt.md"
STARTUP_LIMIT=180 # seconds to wait for "Created session" before giving up

# Duo model ids (gitlab_identifier). Bump here when a new version ships.
duo_model_id() {
  case $1 in
    opus) echo claude_opus_5_5 ;;
    sonnet) echo claude_sonnet_5_5 ;;
    haiku) echo claude_haiku_5_5 ;;
    *) echo "$1" ;;
  esac
}

slug="" cwd="" model="" timeout_s=3600 idle_s=900 resume="" read_only=0 no_check=0 goal=""

usage() {
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit "${1:-1}"
}
die() { echo "${0##*/}: $*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --slug) slug="${2:?}"; shift 2 ;;
    --cwd) cwd="${2:?}"; shift 2 ;;
    --model) model="${2:?}"; shift 2 ;;
    --timeout) timeout_s="${2:?}"; shift 2 ;;
    --idle) idle_s="${2:?}"; shift 2 ;;
    --resume) resume="${2:?}"; shift 2 ;;
    --read-only) read_only=1; shift ;;
    --no-check) no_check=1; shift ;;
    -h | --help) usage 0 ;;
    --) shift; break ;;
    -*) die "unknown option: $1" ;;
    *) [[ -z $goal ]] || die "unexpected extra argument: $1"; goal="$1"; shift ;;
  esac
done
if (($#)); then [[ -z $goal ]] || die "unexpected extra argument: $1"; goal="$1"; fi

[[ $slug =~ ^[a-z0-9-]+$ ]] || die "--slug is required and must match [a-z0-9-]+"
[[ -n $cwd && -d $cwd ]] || die "--cwd must be an existing directory (the worktree Duo works in)"
[[ $timeout_s =~ ^[0-9]+$ && $idle_s =~ ^[0-9]+$ ]] || die "--timeout/--idle must be integers"
[[ -z $resume || $resume =~ ^[0-9]+$ ]] || die "--resume takes a numeric Duo session id"
if [[ -z $goal && ! -t 0 ]]; then goal="$(cat)"; fi
[[ -n $goal ]] || die "goal is required (argument or stdin)"
command -v glab >/dev/null || die "glab not found"
command -v jq >/dev/null || die "jq not found"

cwd="$(cd "$cwd" && pwd)"
mkdir -p "$RUNS_DIR"

# On --resume, find the run that started this session: it has the original goal
# (the checker judges against that, not "continue") and the model to keep.
prev_dir=""
if [[ -n $resume ]]; then
  prev_dir="$(grep -lE "\"sessionId\": *\"$resume\"" "$RUNS_DIR"/*/verdict.json 2>/dev/null |
    xargs -r ls -t 2>/dev/null | tail -1 | xargs -r dirname || true)"
  if [[ -z $model && -n $prev_dir && -f $prev_dir/model.txt ]]; then model="$(<"$prev_dir/model.txt")"; fi
fi
model_id="$(duo_model_id "${model:-sonnet}")"

ts="$(date +%Y%m%d-%H%M%S)"
dir="$(mktemp -d "$RUNS_DIR/$ts-$slug.XXXX")"
E="$dir/stderr.log" R="$dir/result.json"
printf '%s\n' "$model_id" >"$dir/model.txt"

log() { echo "[duo-subagent $slug] $*" >&2; }

# --- preflight: one binary update check at a time, at most every 12 h ---------
preflight() {
  local lock="$RUNS_DIR/.preflight.lock" stamp="$RUNS_DIR/.preflight-ok" n=0
  until mkdir "$lock" 2>/dev/null; do
    ((++n > 120)) && { log "preflight lock busy for 120s; skipping preflight"; return 0; }
    sleep 1
  done
  trap 'rmdir "$RUNS_DIR/.preflight.lock" 2>/dev/null || true' EXIT
  if [[ ! -f $stamp || -n $(find "$stamp" -mmin +720 2>/dev/null) ]]; then
    if glab duo cli --version >"$RUNS_DIR/.preflight.log" 2>&1; then touch "$stamp"; fi
  fi
  rmdir "$lock" 2>/dev/null || true
  trap - EXIT
}
preflight

# --- goal ----------------------------------------------------------------------
if ((read_only)); then
  goal="READ-ONLY TASK: do not create, edit or delete any files and do not run commands that change the repository or system state. Only read, search and run read-only commands.

$goal"
fi
printf '%s\n' "$goal" >"$dir/goal.txt"
if [[ -n $prev_dir ]]; then
  cp "$prev_dir/original-goal.txt" "$dir/original-goal.txt" 2>/dev/null ||
    cp "$prev_dir/goal.txt" "$dir/original-goal.txt"
fi

# --- subagents: user-level + repo-level, repo wins on name clash --------------
# Frontmatter keys: name, description (plain or `>`/`|` block), tools (comma
# list, [a, b] or YAML list). Body = prompt. Not a full YAML parser: files that
# yield no valid agent are reported and listed in agents-dropped.txt.
agent_md_to_json() {
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^["\x27]|["\x27]$/, "", s); return s }
    NR == 1 && /^---[ \t]*$/ { fm = 1; next }
    fm && /^---[ \t]*$/ { fm = 0; body = 1; next }
    fm {
      if (block != "" && $0 ~ /^[ \t]+[^ \t]/) { v = trim($0); val[block] = val[block] (val[block] == "" ? "" : " ") v; next }
      block = ""
      if ($0 ~ /^[ \t]*-[ \t]+/ && key == "tools") { t = $0; sub(/^[ \t]*-[ \t]+/, "", t); val["tools"] = val["tools"] (val["tools"] ? "," : "") trim(t); next }
      if (match($0, /^[A-Za-z_]+:/)) {
        key = substr($0, 1, RLENGTH - 1); v = trim(substr($0, RLENGTH + 1))
        if (v ~ /^[>|][-+]?$/) { block = key; val[key] = ""; next }
        if (key == "tools") gsub(/[\[\]]/, "", v)
        val[key] = v
      }
      next
    }
    body { prompt = prompt $0 "\n" }
    END { printf "%s\x1f%s\x1f%s\x1f%s", val["name"], val["description"], val["tools"], prompt }
  ' "$1" | jq -Rs 'split("\u001f") | {name: .[0], description: .[1],
        toolset: (.[2] | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))),
        prompt: (.[3] | gsub("^\\s+|\\s+$"; ""))}
      | select(.name != "" and .description != "" and .prompt != "")'
}
agents_json=""
shopt -s nullglob
agent_files=("$USER_AGENTS_DIR"/*.md)
if ((${#agent_files[@]})); then
  # --agents replaces the repo's agents entirely, so they must be merged in here.
  agent_files+=("$cwd"/.agents/agents/*.md)
  : >"$dir/agents.jsonl"
  for f in "${agent_files[@]}"; do
    a="$(agent_md_to_json "$f")"
    if [[ -n $a ]]; then printf '%s\n' "$a" >>"$dir/agents.jsonl"
    else log "agent file skipped (missing name/description/body or unsupported YAML): $f"; echo "$f" >>"$dir/agents-dropped.txt"; fi
  done
  agents_json="$(jq -sc 'reverse | unique_by(.name)' "$dir/agents.jsonl")" # reverse: later (repo) files win
  rm -f "$dir/agents.jsonl"
  [[ $agents_json == "[]" ]] && agents_json=""
fi
shopt -u nullglob
if [[ -n $agents_json ]]; then printf '%s\n' "$agents_json" | jq . >"$dir/agents.json"; fi

# --- worktree snapshot: content-level, so edits to already-dirty files count ---
snapshot() { # prints HEAD and a tree id of the full working tree (incl. untracked)
  local idx head tree
  head="$(git -C "$cwd" rev-parse HEAD 2>/dev/null || echo none)"
  idx="$(mktemp)"
  if cp "$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)/index" "$idx" 2>/dev/null &&
    GIT_INDEX_FILE="$idx" git -C "$cwd" add -A >/dev/null 2>&1; then
    tree="$(GIT_INDEX_FILE="$idx" git -C "$cwd" write-tree 2>/dev/null || echo none)"
  else
    tree=none
  fi
  rm -f "$idx"
  echo "$head $tree"
}

# --- run -----------------------------------------------------------------------
args=(-C "$cwd" --log-level info --no-color run --model "$model_id" --output-format json --goal "$goal")
[[ -n $resume ]] && args+=(--existing-session-id "$resume")
[[ -n $agents_json ]] && args+=(--agents "$agents_json")
printf '%q ' glab duo cli "${args[@]}" >"$dir/cmd.txt"

base="$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)"
printf '%s\n' "$base" >"$dir/head.before.txt"
git -C "$cwd" status --porcelain >"$dir/git-status.before.txt" 2>/dev/null || true
snap_before="$(snapshot)"
start=$(date +%s)
log "run dir $dir (model $model_id, timeout ${timeout_s}s, idle ${idle_s}s)"

: >"$E"
# --foreground keeps Duo in our process group, so when the caller (pi's bash
# tool) kills the group on timeout/Esc, Duo dies with it.
timeout --foreground -k 30 "$timeout_s" glab duo cli "${args[@]}" >"$R" 2>>"$E" &
pid=$!

# Watchdog:
# - model fallback: Duo resolves the model before "Created session"; positive
#   fallback lines kill at once, and a missing "Using user-selected model" line
#   once the session exists means the sentinel default (debug-only log) was used.
# - startup: no session after STARTUP_LIMIT seconds.
# - idle: no log output for idle_s seconds (model turns are silent; keep high).
(
  set +e
  trap - ERR
  model_checked=0
  [[ -n $resume ]] && model_checked=1 # resumed runs may not re-log the model
  kill_duo() { echo "watchdog: $1; killing" >>"$E"; kill -TERM "$pid" 2>/dev/null; }
  while kill -0 "$pid" 2>/dev/null; do
    if ((model_checked)); then sleep 10; else sleep 2; fi
    now=$(date +%s)
    if ((!model_checked)); then
      if grep -qE 'Using (default|pinned) model|Model selection (overridden|ignored)' "$E"; then
        kill_duo "model fallback - Duo did not use requested model $model_id"; break
      elif grep -q 'Created session: [0-9]' "$E"; then
        model_checked=1
        if ! grep -qF "Using user-selected model: \"$model_id\"" "$E"; then
          kill_duo "model fallback - Duo did not use requested model $model_id"; break
        fi
      elif ((now - start > STARTUP_LIMIT)); then
        kill_duo "startup - no session after ${STARTUP_LIMIT}s"; break
      fi
    fi
    idle=$((now - $(stat -f %m "$E")))
    if ((idle > idle_s)); then kill_duo "idle ${idle}s with no log output"; break; fi
  done
) &
wd=$!
rc=0
wait "$pid" || rc=$?
kill "$wd" 2>/dev/null || true
wait "$wd" 2>/dev/null || true
end=$(date +%s)
log "duo exited $rc after $((end - start))s"

# --- session id: JSON first, stderr scrape survives a kill ---------------------
sid="$(jq -r '.sessionId // empty' "$R" 2>/dev/null || true)"
[[ -z $sid ]] && sid="$(grep -oE 'Created session: [0-9]+' "$E" | head -1 | grep -oE '[0-9]+$' || true)"
[[ -z $sid ]] && sid="$resume"

# --- deterministic precheck ----------------------------------------------------
count() { grep -cE "$1" "$E" 2>/dev/null || true; }
json_ok=false
jq -e 'type == "object"' "$R" >/dev/null 2>&1 && json_ok=true
model_used=false
grep -qF "Using user-selected model: \"$model_id\"" "$E" && model_used=true
if [[ -n $resume ]] && ! grep -q 'Using .* model: "' "$E"; then model_used=unknown; fi
disposition="$(grep -oE 'Workflow turn ended: [a-z_]+' "$E" | tail -1 | awk '{print $NF}' || true)"
lost_tail=$(count "turn's tail was lost")
[[ -z $disposition && $lost_tail -gt 0 ]] && disposition=incomplete

git -C "$cwd" status --porcelain >"$dir/git-status.txt" 2>/dev/null || true
if [[ -n $base ]]; then
  git -C "$cwd" diff --stat "$base" >"$dir/diff.stat" 2>/dev/null || true
  git -C "$cwd" log --oneline "$base"..HEAD >"$dir/commits.txt" 2>/dev/null || true
else
  : >"$dir/diff.stat"; : >"$dir/commits.txt"
fi
git -C "$cwd" rev-parse HEAD >"$dir/head.after.txt" 2>/dev/null || true
commits=$(grep -c . "$dir/commits.txt" || true)
snap_after="$(snapshot)"
tree_changed=false
[[ $snap_before == "$snap_after" && $snap_before != *none* ]] || tree_changed=true

jq -n \
  --argjson rc "$rc" --arg sid "$sid" --arg model "$model_id" --argjson secs "$((end - start))" \
  --argjson jsonOk "$json_ok" --arg modelUsed "$model_used" --arg disposition "$disposition" \
  --argjson lostTail "$lost_tail" \
  --argjson retries "$(count 'retrying in')" \
  --argjson fatal "$(count 'Max retries exceeded|Failed to initialize workflow|Workflow failed:')" \
  --argjson sessionEnded "$(count 'Previous session has ended')" \
  --argjson openDelegations "$(count 'still in progress; no result was returned')" \
  --argjson failedDelegations "$(count 'Delegation to .* failed')" \
  --argjson watchdogIdle "$(count '^watchdog: idle')" \
  --argjson watchdogModel "$(count '^watchdog: model fallback')" \
  --argjson watchdogStartup "$(count '^watchdog: startup')" \
  --argjson treeChanged "$tree_changed" --argjson readOnly "$read_only" --argjson commits "$commits" \
  --argjson resumed "$([[ -n $resume ]] && echo true || echo false)" \
  '{exitCode:$rc, sessionId:$sid, seconds:$secs, jsonOk:$jsonOk, requestedModel:$model,
    modelUsed:$modelUsed, disposition:$disposition, lostTail:$lostTail, retries:$retries,
    fatalLogLines:$fatal, sessionEnded:$sessionEnded, openDelegations:$openDelegations,
    failedDelegations:$failedDelegations, watchdogIdle:$watchdogIdle, watchdogModel:$watchdogModel,
    watchdogStartup:$watchdogStartup, timedOut:($rc == 124 or $rc == 137), resumed:$resumed,
    treeChanged:$treeChanged, commits:$commits, readOnlyViolated:($readOnly == 1 and $treeChanged)}' \
  >"$dir/precheck.base.json"

if [[ $json_ok == true ]]; then
  # repeatedCalls: identical call AND identical output 3+ times = a real loop
  # (rerunning the same test between fixes gives different output).
  jq '{status, error, responseEmpty: ((.response // "") | length == 0),
       errorElements: [.elements[]? | select(.type == "error") | {error: (.error | tostring | .[0:300]), kind}],
       unfinishedTools: [.elements[]? | select(.type == "tool" and (.state.type == "loading" or .state.type == "approval_request")) | .name],
       toolErrors: [.elements[]? | select(.type == "tool" and .state.type == "error") | {name, error: (.state.error | tostring | .[0:300])}],
       failedCommands: [.elements[]? | select(.type == "tool" and ((.state.output // "") | tostring | test("^Exit code: [1-9]")))
                        | {command: (.input.command // .input | tostring | .[0:200]), output: (.state.output | tostring | .[0:300])}],
       repeatedCalls: ([.elements[]? | select(.type == "tool")
                        | {name, i: (.input | tostring), o: ((.state.output // .state.error // "") | tostring | .[0:500])}]
                       | group_by(.) | map(select(length >= 3)) | map({name: .[0].name, count: length}))}' \
    "$R" >"$dir/precheck.result.json"
else
  echo '{}' >"$dir/precheck.result.json"
fi
jq -s add "$dir/precheck.base.json" "$dir/precheck.result.json" >"$dir/precheck.json"
rm -f "$dir/precheck.base.json" "$dir/precheck.result.json"

# Infra reasons decided without an LLM; they override the checker's verdict.
infra="$(jq -c '[
    (select(.exitCode != 0) | "exit code \(.exitCode)"),
    (select(.jsonOk | not) | "no valid JSON result"),
    (select(.status? and .status != "success") | "status \(.status)"),
    (select(.responseEmpty == true) | "empty response"),
    (select(.disposition != "" and .disposition != "finished" and .disposition != "awaiting_input") | "turn disposition \(.disposition)"),
    (select(.disposition == "" and .exitCode == 0) | "no turn disposition logged"),
    (select(.lostTail > 0) | "stream tail lost"),
    (select(.fatalLogLines > 0) | "fatal log lines"),
    (select(.sessionEnded > 0) | "session ended (cannot resume)"),
    (select(.watchdogIdle > 0) | "idle watchdog kill"),
    (select(.watchdogStartup > 0) | "no session within startup limit"),
    (select(.watchdogModel > 0 or .modelUsed == "false") | "model fallback (not \(.requestedModel))"),
    (select(.timedOut) | "timed out"),
    (select(.openDelegations > 0) | "delegation never returned"),
    ((.unfinishedTools // []) | select(length > 0) | "unfinished tool calls")
  ]' "$dir/precheck.json")"

# --- full transcript (server-side; works after a crash) ------------------------
if [[ -n $sid ]]; then
  for attempt in 1 2; do
    if glab duo cli -C "$cwd" --log-level error --no-color export --existing-session-id "$sid" \
      -o "$dir/export.json" >/dev/null 2>"$dir/export.err" && jq -e . "$dir/export.json" >/dev/null 2>&1; then
      break
    fi
    rm -f "$dir/export.json"
    ((attempt == 1)) && sleep 10
  done
fi
[[ -f $dir/export.json ]] || log "transcript export failed (see $dir/export.err)"

# --- checker -------------------------------------------------------------------
verdict_fallback() { # $1 = verdict, $2 = action, $3 = detail (infra issues are added below)
  jq -n --arg v "$1" --arg a "$2" --arg d "$3" \
    '{verdict:$v, goalCompleted:false, confidence:"low", suggestedAction:$a, followupGoal:"",
      issues: (if $d == "" then [] else [{severity:"major", kind:"other", evidence:"", detail:$d}] end)}'
}

if ((no_check)); then
  if [[ $infra == "[]" ]]; then verdict_fallback UNCHECKED accept "checker skipped (--no-check)"
  else verdict_fallback INFRA resume_continue ""; fi >"$dir/check.json"
else
  if [[ -n $resume ]]; then
    if [[ -f $dir/original-goal.txt ]]; then
      resumed="This run RESUMED Duo session $resume. goal.txt is only the follow-up message; judge completion against original-goal.txt (the task that started the session) plus goal.txt."
    else
      resumed="This run RESUMED Duo session $resume. goal.txt is only the follow-up message; judge completion against the first user goal in export.json (summary.userGoals) plus goal.txt."
    fi
  else
    resumed="This is a fresh session; goal.txt is the full task."
  fi
  p="$(<"$CHECKER_PROMPT")"
  ro=no; ((read_only)) && ro=yes
  # quoted replacements: bash 5.2 patsub_replacement would expand & otherwise
  # (unquoted assignment on purpose: outer quotes would make the inner ones literal)
  p=${p//'{{DIR}}'/"$dir"}
  p=${p//'{{CWD}}'/"$cwd"}
  p=${p//'{{INFRA}}'/"$infra"}
  p=${p//'{{MODEL}}'/"$model_id"}
  p=${p//'{{READ_ONLY}}'/"$ro"}
  p=${p//'{{RESUMED}}'/"$resumed"}
  printf '%s\n' "$p" >"$dir/checker-prompt.md"
  check_slug="duo-check-$(basename "$dir" | tr 'A-Z.' 'a-z-' | tr -cd 'a-z0-9-' | sed 's/-*$//')"
  (cd "$cwd" && "$SUBAGENT" --slug "$check_slug" --model sonnet --timeout 900 \
    <"$dir/checker-prompt.md" >"$dir/check.md" 2>"$dir/check.err") || log "checker exited non-zero (see $dir/check.err)"
  # last fenced ```json block; fall back to the last line that looks like a verdict object
  awk '/^```json[[:space:]]*$/ {f = 1; b = ""; next} /^```[[:space:]]*$/ {if (f) last = b; f = 0; next} f {b = b $0 "\n"} END {printf "%s", last}' \
    "$dir/check.md" >"$dir/check.json"
  if ! jq -e . "$dir/check.json" >/dev/null 2>&1; then
    grep -E '^\{.*"verdict"' "$dir/check.md" | tail -1 >"$dir/check.json" || true
  fi
  if ! jq -e '.verdict | IN("PASS", "PARTIAL", "FAIL", "INFRA")' "$dir/check.json" >/dev/null 2>&1; then
    verdict_fallback UNKNOWN escalate "checker produced no valid verdict (see $dir/check.md)" >"$dir/check.json"
  fi
  # PASS requires goalCompleted
  jq 'if .verdict == "PASS" and .goalCompleted != true then .verdict = "PARTIAL" else . end' \
    "$dir/check.json" >"$dir/check.json.tmp" && mv "$dir/check.json.tmp" "$dir/check.json"
  # prose = everything before the last ```json fence
  last_fence=$(grep -nE '^```json[[:space:]]*$' "$dir/check.md" | tail -1 | cut -d: -f1 || true)
  awk -v n="${last_fence:-0}" 'n == 0 || NR < n' "$dir/check.md"
fi

# Deterministic infra findings win over the LLM verdict.
if [[ $infra != "[]" ]]; then
  jq --argjson infra "$infra" '
    .verdict = "INFRA"
    | .suggestedAction = (
        if any($infra[]; startswith("model fallback") or startswith("session ended")) then "rerun_fresh"
        elif any($infra[]; startswith("no session within")) then "escalate"
        elif .suggestedAction == "accept" or .suggestedAction == null then "resume_continue"
        else .suggestedAction end)
    | .issues = ([$infra[] | {severity:"blocker", kind:(if startswith("model fallback") then "wrong_model" else "infra" end),
                              evidence:"precheck.json", detail:.}] + (.issues // []))' \
    "$dir/check.json" >"$dir/check.json.tmp" && mv "$dir/check.json.tmp" "$dir/check.json"
fi

# --read-only run that changed the tree: never PASS, caller must inspect/revert.
if ((read_only)) && [[ $tree_changed == true ]]; then
  jq '.verdict = (if .verdict == "PASS" or .verdict == "PARTIAL" then "FAIL" else .verdict end)
      | .suggestedAction = "escalate"
      | .issues = ([{severity:"blocker", kind:"scope_creep", evidence:"worktree snapshot before/after",
                     detail:"read-only run changed the worktree; inspect git diff/status and revert Duo'"'"'s changes"}] + (.issues // []))' \
    "$dir/check.json" >"$dir/check.json.tmp" && mv "$dir/check.json.tmp" "$dir/check.json"
fi

jq -n --arg dir "$dir" --arg sid "$sid" --argjson rc "$rc" --arg model "$model_id" \
  --slurpfile pre "$dir/precheck.json" --slurpfile c "$dir/check.json" \
  '{dir:$dir, sessionId:$sid, model:$model, exitCode:$rc, readOnlyViolated:$pre[0].readOnlyViolated, commits:$pre[0].commits}
   + ($c[0] | {verdict, goalCompleted, suggestedAction, followupGoal, issues})' \
  >"$dir/verdict.json"
jq -c . "$dir/verdict.json"

trap - ERR
[[ $(jq -r .verdict "$dir/verdict.json") == PASS ]] && exit 0 || exit 2
