#!/usr/bin/env bash
# tabs.sh — inspect and drive the zellij tabs of task sessions.
#
#   tabs.sh ls [-v] [<task-id>...]          tabs + panes of live task sessions (-v: last lines of each pane)
#   tabs.sh agents [-n N] [<task-id>...]     state of every pi pane: WORKING / ASKING / IDLE + its last N message lines
#   tabs.sh peek <task-id> [<pane>] [-n N] [--full]   screen of one pane (default: first terminal pane)
#   tabs.sh new <task-id> [-n <name>] [-c <cwd>] [-- <cmd...>]   open a tab (cmd runs in fish, then drops to fish)
#   tabs.sh run <task-id> <pane> <text...>  type text into a pane and press Enter
#   tabs.sh keys <task-id> <pane> <key>...  send raw keys, e.g. "Ctrl c"  Enter  Esc
#   tabs.sh close <task-id> <tab-id>        close a tab (refuses to close the last one)
#
# <pane> is a zellij pane id: 3 or terminal_3. <tab-id> is the stable TAB_ID from `ls`.
set -euo pipefail

PREFIX="${TASK_SESSION_PREFIX:-ts-}"

die() { echo "tabs: $*" >&2; exit 1; }

session_of() { echo "${PREFIX}$1"; }

live_sessions() {
  # names of non-exited sessions carrying the task prefix
  zellij list-sessions -n 2>/dev/null | grep -v 'EXITED' | awk '{print $1}' | grep "^${PREFIX}" || true
}

require_live() {
  local s; s=$(session_of "$1")
  live_sessions | grep -qx "$s" || die "no live session '$s' for task '$1' (done, exited, or never started)"
}

z() { local s=$1; shift; zellij -s "$s" action "$@"; }

panes_json() { z "$1" list-panes -a -j; }

norm_pane() { [[ $1 == terminal_* || $1 == plugin_* ]] && echo "$1" || echo "terminal_$1"; }

screen_tail() { # session pane lines
  z "$1" dump-screen -p "$2" 2>/dev/null | sed 's/[[:space:]]*$//' | grep -v '^$' | tail -n "$3" || true
}

has_client() { [[ $(z "$1" list-clients 2>/dev/null | tail -n +2 | grep -c .) -gt 0 ]]; }

cmd_ls() {
  local verbose=0 ids=()
  while (($#)); do case $1 in -v) verbose=1 ;; *) ids+=("$1") ;; esac; shift; done
  local tasks; tasks=$(task list --json 2>/dev/null || echo '[]')
  if ((${#ids[@]} == 0)); then
    while read -r s; do [[ -n $s ]] && ids+=("${s#"$PREFIX"}"); done < <(live_sessions)
  fi
  local me="${TASK_ID:-}"
  for id in "${ids[@]}"; do
    local s; s=$(session_of "$id")
    local meta; meta=$(jq -r --arg id "$id" '.[]|select(.id==$id)|"\(.status) · \(.category // "-") · \(.name)"' <<<"$tasks")
    [[ -z $meta ]] && meta="(no task file — orphan session)"
    local mark=""; [[ $id == "$me" ]] && mark="  ← this session"
    has_client "$s" && mark="$mark  [attached]"
    echo "## $id — $meta$mark"
    local pj; pj=$(panes_json "$s") || { echo "   (unreachable)"; continue; }
    jq -r '
      [.[]|select(.is_plugin|not)] | group_by(.tab_id)[] |
      "  tab \(.[0].tab_id) \"\(.[0].tab_name)\"",
      (.[] | "    terminal_\(.id)  \(.title)"
        + (if .terminal_command then "  cmd: \(.terminal_command)" else "" end)
        + (if .exited then "  [EXITED \(.exit_status)]" else "" end)
        + (if .is_floating then "  [floating]" else "" end))
    ' <<<"$pj"
    if ((verbose)); then
      for p in $(jq -r '.[]|select(.is_plugin|not)|"terminal_\(.id)"' <<<"$pj"); do
        echo "    ┄ $p"
        screen_tail "$s" "$p" 4 | cut -c1-160 | sed 's/^/      │ /'
      done
    fi
    echo
  done
}

# Split a pi screen into its state and the tail of the last message.
# pi draws: <conversation> / ── [⠼ Working] ── / <editor> / ──── / <footer lines>.
# The editor sits between the two bottom-most separators; the conversation ends
# just above the upper one, which carries "Working" while a turn is running.
pi_state() { # session pane lines
  z "$1" dump-screen -p "$2" 2>/dev/null | sed 's/[[:space:]]*$//' | grep -v '^$' | awk -v n="$3" '
    { l[NR] = $0 }
    END {
      found = 0
      for (i = NR; i > 0 && found < 2; i--) if (l[i] ~ /^ *──/) { found++; upper = i }
      if (found < 2) { print "UNKNOWN"; for (m = (NR - n + 1 > 1 ? NR - n + 1 : 1); m <= NR; m++) print l[m]; exit }
      working = (l[upper] ~ /Working/)
      last = upper - 1
      state = working ? "WORKING" : (l[last] ~ /\?[*_`) ]*$/ ? "ASKING" : "IDLE")
      print state
      for (m = (last - n + 1 > 1 ? last - n + 1 : 1); m <= last; m++) print l[m]
    }'
}

cmd_agents() {
  local n=3 ids=()
  while (($#)); do case $1 in -n) n=$2; shift ;; *) ids+=("$1") ;; esac; shift; done
  if ((${#ids[@]} == 0)); then
    while read -r s; do [[ -n $s ]] && ids+=("${s#"$PREFIX"}"); done < <(live_sessions)
  fi
  for id in "${ids[@]}"; do
    local s; s=$(session_of "$id")
    local pj; pj=$(panes_json "$s" 2>/dev/null) || continue
    while IFS=$'\t' read -r pane tab tabname; do
      [[ -z $pane ]] && continue
      [[ $id == "${TASK_ID:-}" && $pane == "terminal_${ZELLIJ_PANE_ID:-}" ]] && continue   # that's me
      local out; out=$(pi_state "$s" "$pane" "$n")
      echo "$id · tab $tab \"$tabname\" · $pane · $(head -1 <<<"$out")"
      tail -n +2 <<<"$out" | cut -c1-200 | sed 's/^ */    │ /'
    done < <(jq -r '.[]|select((.is_plugin|not) and (.title|startswith("π")) and (.exited|not))|"terminal_\(.id)\t\(.tab_id)\t\(.tab_name)"' <<<"$pj")
  done
}

cmd_peek() {
  local id=${1:?task id}; shift
  local pane="" n=40 full=0
  while (($#)); do case $1 in -n) n=$2; shift ;; --full) full=1 ;; *) pane=$(norm_pane "$1") ;; esac; shift; done
  require_live "$id"; local s; s=$(session_of "$id")
  [[ -z $pane ]] && pane=$(panes_json "$s" | jq -r '[.[]|select(.is_plugin|not)][0]|"terminal_\(.id)"')
  if ((full)); then
    z "$s" dump-screen -f -p "$pane" | sed 's/[[:space:]]*$//' | grep -v '^$' | tail -n "$n"
  else
    screen_tail "$s" "$pane" "$n"
  fi
}

kdl_escape() { local x=${1//\\/\\\\}; echo "${x//\"/\\\"}"; }

cmd_new() {
  local id=${1:?task id}; shift
  local name="" cwd="" cmd=""
  while (($#)); do
    case $1 in
      -n) name=$2; shift ;;
      -c) cwd=$2; shift ;;
      --) shift; cmd="$*"; break ;;
      *) die "unknown arg '$1' (put the command after --)" ;;
    esac; shift
  done
  require_live "$id"; local s; s=$(session_of "$id")
  [[ -z $cwd ]] && cwd=$(task get "$id" cwd 2>/dev/null || echo "$HOME")
  [[ -z $name ]] && name=$( [[ -n $cmd ]] && basename "${cmd%% *}" || echo shell )

  # Same shape as task's own layout: tab-bar on top, fish pane that survives the command.
  local pane_kdl
  if [[ -z $cmd ]]; then
    pane_kdl="pane command=\"fish\" focus=true"
  else
    pane_kdl="pane command=\"fish\" focus=true { args \"-c\" \"$(kdl_escape "$cmd"); exec fish\"; }"
  fi
  local layout="layout { pane size=1 borderless=true { plugin location=\"tab-bar\"; }; $pane_kdl; }"

  local before; before=$(panes_json "$s" | jq '[.[]|select(.is_plugin|not)|.id]')

  # zellij 0.45: new-tab on a session with no attached client creates an EMPTY tab (no pane).
  # Attach a throwaway client in a detached tmux for the duration of the call.
  local tmux_s=""
  if ! has_client "$s"; then
    command -v tmux >/dev/null || die "session has no client and tmux is missing — can't open a tab headless"
    tmux_s="tabs-$$"
    tmux new-session -d -s "$tmux_s" -x 220 -y 60 \
      "env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID zellij attach $s"
    for _ in $(seq 1 30); do has_client "$s" && break; sleep 0.2; done
    has_client "$s" || { tmux kill-session -t "$tmux_s" 2>/dev/null; die "temp client failed to attach to $s"; }
  else
    echo "note: a client is attached to $s — zellij will switch its view to the new tab" >&2
  fi

  local tab_id
  tab_id=$(z "$s" new-tab -n "$name" -c "$cwd" --layout-string "$layout" | tail -1)
  sleep 1
  [[ -n $tmux_s ]] && tmux kill-session -t "$tmux_s" 2>/dev/null || true

  local new; new=$(panes_json "$s" | jq -r --argjson b "$before" \
    '[.[]|select((.is_plugin|not) and (.id as $i | $b | index($i) | not))][0] // empty | "terminal_\(.id)"')
  if [[ -z $new ]]; then
    z "$s" close-tab-by-id "$tab_id" 2>/dev/null || true
    die "tab $tab_id came up without a pane — closed it"
  fi
  echo "tab $tab_id \"$name\" → $new  (cwd $cwd)"
}

cmd_run() {
  local id=${1:?task id} pane; pane=$(norm_pane "${2:?pane}"); shift 2
  (($#)) || die "nothing to type"
  require_live "$id"; local s; s=$(session_of "$id")
  z "$s" write-chars -p "$pane" "$*"
  z "$s" send-keys -p "$pane" Enter
  sleep "${TABS_SETTLE:-1.5}"
  screen_tail "$s" "$pane" 15
}

cmd_keys() {
  local id=${1:?task id} pane; pane=$(norm_pane "${2:?pane}"); shift 2
  require_live "$id"; local s; s=$(session_of "$id")
  z "$s" send-keys -p "$pane" "$@"
  sleep 0.7
  screen_tail "$s" "$pane" 10
}

cmd_close() {
  local id=${1:?task id} tab=${2:?tab id}
  require_live "$id"; local s; s=$(session_of "$id")
  local tabs; tabs=$(z "$s" list-tabs -j)
  jq -e --argjson t "$tab" 'any(.[]; .tab_id==$t)' <<<"$tabs" >/dev/null || die "no tab $tab in $s"
  (($(jq length <<<"$tabs") > 1)) || die "tab $tab is the last tab in $s — closing it ends the session; use 'task done $id' instead"
  z "$s" close-tab-by-id "$tab"
  echo "closed tab $tab in $s"
}

sub=${1:-ls}; shift || true
case $sub in
  ls) cmd_ls "$@" ;;
  agents) cmd_agents "$@" ;;
  peek) cmd_peek "$@" ;;
  new) cmd_new "$@" ;;
  run) cmd_run "$@" ;;
  keys) cmd_keys "$@" ;;
  close) cmd_close "$@" ;;
  -h|--help|help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown subcommand '$sub' (ls|agents|peek|new|run|keys|close)" ;;
esac
