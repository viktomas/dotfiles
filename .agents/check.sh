#!/bin/sh
# Scaffolding check for the dotfiles repo (agent-scaffolding phases 1-3;
# see .agents/PLAN.md). No CI in this repo, so this is the nearest
# equivalent — run it before committing scaffolding changes:
#   .agents/check.sh
#
# The AGENTS.md budget is a placeholder the owner may tighten; at budget,
# one line must go to make room for a new one.

set -eu
cd "$(dirname "$0")/.."

AGENTS_BUDGET=28
out=$(mktemp)
fail() { echo "FAIL $*" >>"$out"; }

# --- AGENTS.md budget ------------------------------------------------------
n=$(grep -c '' AGENTS.md)
[ "$n" -le "$AGENTS_BUDGET" ] ||
  fail "AGENTS.md is $n lines, over the $AGENTS_BUDGET-line budget - delete a line to make room (.agents/AUDIT.md has provenance)"

# --- .agents/ must never become a stow package ----------------------------
grep -qE 'stow +\.agents($| )' install.sh &&
  fail "install.sh stows .agents - it is repo state, not a package (~/.agents is the agents/ package's own .agents)"

# --- skill validator -------------------------------------------------------
for skill in .pi/skills/*/; do
  name=$(basename "$skill")
  f="$skill/SKILL.md"
  if [ ! -f "$f" ]; then fail "$name: skill directory has no SKILL.md"; continue; fi

  fm_name=$(sed -n 's/^name:[[:space:]]*//p' "$f" | head -1 | tr -d '[:space:]')
  [ "$fm_name" = "$name" ] ||
    fail "$name: frontmatter name '$fm_name' must match the directory name"

  desc=$(sed -n 's/^description:[[:space:]]*//p' "$f" | head -1)
  words=$(printf '%s' "$desc" | wc -w | tr -d ' ')
  { [ "$words" -ge 30 ] && [ "$words" -le 55 ]; } ||
    fail "$name: description is $words words; trigger descriptions are 30-55 - say when to load the skill, not what it contains"
  case "$desc" in *"Use "*) ;; *) fail "$name: description must be trigger-style - what it does, then 'Use when ...'";; esac

  # relative markdown-link targets must exist (skip http, anchors; and
  # scan only outside fenced code blocks - the decode examples contain
  # bracket-paren sequences like [faint]([base]now that are not links)
  awk '/^```/{f=!f; next} !f' "$f" | grep -oE '\]\([^)]+\)' | sed 's/](//; s/)$//' | while IFS= read -r tgt; do
    case "$tgt" in *://*|\#*) continue ;; esac
    tgt=${tgt%% *}   # drop an optional " title" suffix
    tgt=${tgt%.}
    [ -e "$skill$tgt" ] || echo "FAIL $name: link target $tgt does not exist" >>"$out"
  done
done

if [ -s "$out" ]; then
  cat "$out" >&2
  echo "scaffolding check: FAILED" >&2
  rm -f "$out"
  exit 1
fi
rm -f "$out"
echo "scaffolding check: OK"
