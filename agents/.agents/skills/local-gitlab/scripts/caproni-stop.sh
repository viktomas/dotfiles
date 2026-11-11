#!/bin/bash
# Stop `caproni run` for one instance cleanly and leave the cluster in stock mode.
# Usage: caproni-stop.sh <a|b|c>
# - sends C-c to the tmux session (graceful: caproni deletes its *-caproni copies)
# - deletes leftover *-caproni copy deployments and scales originals back to 1
# - kills orphaned local processes (vite, puma, sidekiq, DWS, mirrord) whose cwd is in the instance dir
# - waits until the original deployments are rolled out (the next `caproni run` needs them)
set -uo pipefail
source "$(dirname "$0")/caproni-env.sh" "$1" || exit 1
k() { kubectl --context "$CAPRONI_CTX" "$@"; }

run_pids() {
  for p in $(pgrep -f 'caproni run'); do
    lsof -a -p "$p" -d cwd -Fn 2>/dev/null | grep -q "^n$CAPRONI_DIR" && echo "$p"
  done
}

if tmux has-session -t "$CAPRONI_TMUX" 2>/dev/null; then
  tmux send-keys -t "$CAPRONI_TMUX" C-c
fi
for _ in $(seq 1 40); do [ -z "$(run_pids)" ] && break; sleep 3; done
[ -n "$(run_pids)" ] && { echo "caproni run still alive: $(run_pids) - killing"; kill $(run_pids); sleep 5; }
tmux kill-session -t "$CAPRONI_TMUX" 2>/dev/null

for d in $CAPRONI_ORIGINALS; do
  ns=${d%/*}; name=${d#*/}
  k -n "$ns" get deploy "$name" >/dev/null 2>&1 || continue
  k -n "$ns" delete deploy "$name-caproni" --ignore-not-found >/dev/null
  [ "$(k -n "$ns" get deploy "$name" -o jsonpath='{.spec.replicas}')" = 0 ] && k -n "$ns" scale deploy "$name" --replicas=1 >/dev/null
done

for p in $(pgrep -f 'vite|puma|sidekiq|background_jobs|ai_gateway|duo-workflow-service|mirrord|poetry|overseer'); do
  lsof -a -p "$p" -d cwd -Fn 2>/dev/null | grep -q "^n$CAPRONI_DIR" && { echo "killing orphan $p $(ps -o comm= -p "$p")"; kill "$p" 2>/dev/null; }
done

for d in $CAPRONI_ORIGINALS; do
  k -n "${d%/*}" get deploy "${d#*/}" >/dev/null 2>&1 || continue
  k -n "${d%/*}" rollout status deploy/"${d#*/}" --timeout=400s >/dev/null && echo "ready: $d"
done
