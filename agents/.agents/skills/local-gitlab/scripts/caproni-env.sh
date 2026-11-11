# Sourced by the other scripts: per-instance settings. Usage: source caproni-env.sh <a|b|c>
CAPRONI_INSTANCE="${1:?instance letter (a|b|c) required}"
case "$CAPRONI_INSTANCE" in
  a) CAPRONI_VITE_PORT=3037 ;;
  b) CAPRONI_VITE_PORT=3038 ;;
  c) CAPRONI_VITE_PORT=3039 ;;
  *) echo "unknown instance '$CAPRONI_INSTANCE'" >&2; return 1 2>/dev/null || exit 1 ;;
esac
CAPRONI_DIR="$HOME/workspace/gl/caproni-agent-$CAPRONI_INSTANCE"
CAPRONI_CTX="caproni-$CAPRONI_INSTANCE"
CAPRONI_HOST="gitlab.$CAPRONI_INSTANCE.caproni.test"     # in-cluster hostname, always port 80
CAPRONI_TMUX="caproni-$CAPRONI_INSTANCE-run"
CAPRONI_LOG="/tmp/caproni-run-$CAPRONI_INSTANCE.log"
# Deployments `caproni run` swaps for *-caproni copies (gitlab + sidekiq + ai-gateway reloaders)
CAPRONI_ORIGINALS="gitlab/gitlab-webservice-default gitlab/gitlab-sidekiq-all-in-1-v2 ai-gateway/ai-gateway"
[ -f "$HOME/.secrets/caproni" ] && source "$HOME/.secrets/caproni"
