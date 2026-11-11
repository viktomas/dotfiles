#!/bin/bash
# Start `caproni run` (edit mode) for one instance in a detached tmux session and wait until
# Puma serves the API (and DWS listens, if the ai-gateway reloader is configured).
# Usage: caproni-run.sh <a|b|c> [KEY=VALUE ...]    extra env, e.g. CAPRONI_ACTIVATE_LICENSE=1
# Log: /tmp/caproni-run-<x>.log   tmux: caproni-<x>-run   stop: caproni-stop.sh <x>
#
# Why a generated launcher instead of `tmux new-session "caproni run"`:
# - tmux shells don't get the mise PATH -> hooks run macOS system ruby 2.6 and crash
# - two instances in edit mode collide on Vite's default port 3036
# - DWS's wait-for-gitlab.sh needs CAPRONI_PRIMARY_HOSTNAME, which caproni doesn't pass on
# - no `| tee`: when tee dies, caproni gets SIGPIPE and leaves its copy deployments behind
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/caproni-env.sh" "$1" || exit 1; shift

if tmux has-session -t "$CAPRONI_TMUX" 2>/dev/null; then
  echo "tmux session $CAPRONI_TMUX exists - run caproni-stop.sh $CAPRONI_INSTANCE first" >&2; exit 1
fi
# Leftover copies or scaled-down originals make `caproni run` fail; clean them first.
if kubectl --context "$CAPRONI_CTX" get deploy -A 2>/dev/null | grep -q -- '-caproni '; then
  "$HERE/caproni-stop.sh" "$CAPRONI_INSTANCE"
fi

# DWS (under mirrord, pod DNS) must reach http://$CAPRONI_HOST in-cluster; without the CoreDNS
# rewrite it waits for OIDC, times out and never starts. See duo-remote-flows.md.
if grep -q 'ai-gateway' "$CAPRONI_DIR/caproni.local.yaml" &&
   ! kubectl --context "$CAPRONI_CTX" -n kube-system get cm coredns-custom -o jsonpath='{.data}' 2>/dev/null | grep -q "rewrite name exact $CAPRONI_HOST "; then
  echo "missing CoreDNS rewrite for $CAPRONI_HOST in $CAPRONI_CTX kube-system/coredns-custom (see duo-remote-flows.md)" >&2; exit 1
fi

LAUNCHER=$(mktemp /tmp/caproni-launch-XXXXXX); chmod 700 "$LAUNCHER"
{
  echo '#!/bin/bash'
  printf 'export PATH=%q\n' "$PATH"
  [ -n "${ANTHROPIC_API_KEY:-}" ] && printf 'export ANTHROPIC_API_KEY=%q\n' "$ANTHROPIC_API_KEY"
  [ -n "${NODE_EXTRA_CA_CERTS:-}" ] && printf 'export NODE_EXTRA_CA_CERTS=%q\n' "$NODE_EXTRA_CA_CERTS"
  echo "export CAPRONI_ACTIVATE_LICENSE=0"
  echo "export VITE_RUBY_PORT=$CAPRONI_VITE_PORT"
  echo "export CAPRONI_PRIMARY_HOSTNAME=$CAPRONI_HOST"
  for kv in "$@"; do printf 'export %q\n' "$kv"; done
  echo "rm -f '$LAUNCHER'"
  echo "cd '$CAPRONI_DIR' && caproni run > '$CAPRONI_LOG' 2>&1"
  echo 'echo "caproni run exited ($?)"; sleep 100000'
} > "$LAUNCHER"
: > "$CAPRONI_LOG"
tmux new-session -d -s "$CAPRONI_TMUX" -x 250 -y 50 "$LAUNCHER"

has_dws=$(grep -q 'ai-gateway' "$CAPRONI_DIR/caproni.local.yaml" && echo 1)
token_var="CAPRONI_$(echo "$CAPRONI_INSTANCE" | tr a-z A-Z)_TOKEN"; url_var="CAPRONI_$(echo "$CAPRONI_INSTANCE" | tr a-z A-Z)_URL"
# Fail fast instead of polling the full timeout when something can no longer come up:
# - caproni's own fatal errors start the line with (coloured) ERROR
# - a reloader process that overseer gave up on ("Stopped"), e.g. DWS after its OIDC wait
#   timed out, or a port clash ("already in use" / EADDRINUSE)
# - the launcher's caproni process exited
fatal_re=$'^(\e\\[[0-9;]*m)?ERROR|Process exited abnormally\\. Stopped|Timed out waiting for GitLab OIDC|already in use|EADDRINUSE|caproni run exited'
for i in $(seq 1 60); do
  if grep -a -q -E "$fatal_re" "$CAPRONI_LOG"; then
    echo "caproni run failed (still running in tmux $CAPRONI_TMUX; clean up with caproni-stop.sh $CAPRONI_INSTANCE):"
    grep -a -E "$fatal_re" "$CAPRONI_LOG" | tail -3 | cut -c1-250; exit 1
  fi
  tmux has-session -t "$CAPRONI_TMUX" 2>/dev/null || { echo "tmux session $CAPRONI_TMUX died; tail:"; tail -5 "$CAPRONI_LOG" | cut -c1-200; exit 1; }
  api=$(curl -s -m 5 -o /dev/null -w '%{http_code}' -H "PRIVATE-TOKEN: ${!token_var:-}" "${!url_var:-http://$CAPRONI_HOST}/api/v4/user")
  dws_ok=1; [ -n "$has_dws" ] && ! grep -a -q 'Starting gRPC server' "$CAPRONI_LOG" && dws_ok=
  if grep -a -q 'Listening on http' "$CAPRONI_LOG" && [ "$api" = 200 ] && [ -n "$dws_ok" ]; then
    echo "edit mode up on $CAPRONI_INSTANCE (api 200${has_dws:+, DWS listening}) after $((i*10))s"; exit 0
  fi
  sleep 10
done
echo "timed out; tail of $CAPRONI_LOG:"; tail -5 "$CAPRONI_LOG" | cut -c1-200; exit 1
