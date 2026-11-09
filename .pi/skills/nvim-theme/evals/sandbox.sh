#!/bin/sh
# Phase-5 sandboxed trigger-eval runner (agent-scaffolding). The write-y
# trigger cases (tier-change, compare-options, add-plugin, fish-prompt)
# instruct edits, and the skill's body points at the real ~/.dotfiles via
# absolute paths — so a plain repo copy would send the eval agent's writes
# to the live working tree (which also carries other sessions' uncommitted
# work). This script builds a throwaway copy where that cannot happen:
#
#   1. copy the repo to /tmp (minus 1.4G of pi session data),
#   2. rewrite the skill's absolute ~/.dotfiles references (and
#      nvim/THEME.md, which the skill directs the agent to read) to the
#      copy,
#   3. put an nvim shim first on PATH that prepends the copy's nvim config
#      to 'runtimepath' — lua/user/*, after/queries and init.lua resolve to
#      the copy, while plugins/LSP stay on the real install (the config
#      uses vim.pack, which does not reorder rtp),
#   4. run evals/run.sh from inside the copy, with the case-id filter
#      passed through for single-case iteration,
#   5. afterwards show what the eval agent wrote (sandbox git status) and
#      check for drift in the real vim.pack install dir, then delete the
#      sandbox (SANDBOX_KEEP=1 keeps it for inspection).
#
# Session logs still land in the real ~/.pi/agent/sessions/<sandbox-slug>/
# (gitignored), so run.sh can analyse them afterwards.
#
# Usage: sandbox.sh [case-id ...]    (env: CAP_S, SANDBOX_KEEP)

set -eu

repo=$(cd "$(dirname "$0")/../../../.." && pwd -P)
sandbox=$(mktemp -d /tmp/nvim-theme-eval.XXXXXX)
skill="$sandbox/.pi/skills/nvim-theme"

# 1. throwaway copy of the repo, minus pi session data
rsync -a --exclude 'pi/.pi/agent/sessions' \
          --exclude 'pi/.pi/agent/subagent-sessions' \
          --exclude 'pi/.pi/agent/kickoff-sessions' \
     "$repo"/ "$sandbox"/

# 2. rewrite absolute self-references to the sandbox
for f in "$skill/SKILL.md" "$skill"/references/*.md "$sandbox/nvim/THEME.md"; do
  perl -pi -e "s|\Q~/.dotfiles\E|$sandbox|g; s|\Q$repo\E|$sandbox|g" "$f"
done

# 3. nvim shim: the sandbox's config dir is first on rtp, so everything
#    config-shaped is read from the copy; installed plugins stay real
real_nvim=$(command -v nvim)
mkdir -p "$sandbox/.eval-bin"
cat >"$sandbox/.eval-bin/nvim" <<EOF
#!/bin/sh
exec "$real_nvim" --cmd "let &runtimepath = '$sandbox/nvim/.config/nvim,' . &runtimepath" "\$@"
EOF
chmod +x "$sandbox/.eval-bin/nvim"

# 4. run the suite from inside the copy (cwd = sandbox root, so pi loads
#    the sandbox's AGENTS.md + project skills; global skills stay real)
echo "sandbox: $sandbox"
cd "$sandbox"
before=$(mktemp)
git status --porcelain >"$before"   # post-rewrite baseline: our rewrites and
                                    # the copied uncommitted state are expected
rc=0
PATH="$sandbox/.eval-bin:$PATH" CAP_S="${CAP_S:-120}" \
  sh .pi/skills/nvim-theme/evals/run.sh nvim-theme "$@" || rc=$?

# 5. what did the eval agent write? (delta against the post-rewrite status)
echo "--- writes by the eval agent (git status delta; '>' lines are new)"
git status --porcelain | diff "$before" - || true
rm -f "$before"

# drift check: vim.pack installs into the real data dir — flag anything new
packdir="$HOME/.local/share/nvim/site/pack"
find "$packdir" -maxdepth 3 -mindepth 1 -newer "$sandbox/.eval-bin/nvim" -print 2>/dev/null |
  sed "s|^|pack-drift: |" || true

[ "${SANDBOX_KEEP:-0}" = 1 ] || rm -rf "$sandbox"
exit "$rc"
