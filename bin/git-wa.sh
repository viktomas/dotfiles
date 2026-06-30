#!/bin/bash
#
# Wrapper around `git worktree add` that also runs post-create setup
# (mise trust, npm/bun install, go mod download).
#
# ─── I/O CONTRACT (do not break) ────────────────────────────────────────────
# STDOUT is a MACHINE-READABLE data channel. On success it contains exactly:
#   line 1: the absolute worktree path
# STDERR carries ALL human-facing progress / status / error messages.
#
# This makes the script safe to capture from callers:
#     path=$(~/bin/git-wa.sh <path> <branch-ish...> 2>/dev/null)
#
# The script is idempotent: if the target worktree path already exists it
# reports the path and exits 0 without re-running setup.
#
# First positional arg is always the worktree path (as passed to
# `git worktree add`).
# ────────────────────────────────────────────────────────────────────────────

set -uo pipefail

worktree_arg="${1:?usage: git-wa.sh <path> [git-worktree-add-args...]}"

# ── Idempotency ─────────────────────────────────────────────────────────────
# If the target path already exists, assume the worktree is there and just
# report it. Don't re-run `git worktree add` (which would fail) or setup.
if [ -e "$worktree_arg" ]; then
    abs=$(cd "$worktree_arg" 2>/dev/null && pwd)
    if [ -n "$abs" ]; then
        echo "✓ Worktree already exists: $abs" >&2
        echo "$abs"
        exit 0
    fi
fi

# Forward `git worktree add` output to stderr; keep stdout clean.
if ! git worktree add "$@" 1>&2; then
    echo "git worktree command failed" >&2
    exit 1
fi

worktree_path=$(cd "$worktree_arg" && pwd)
if [ ! -d "$worktree_path" ]; then
    echo "Error: Could not find worktree directory $worktree_path" >&2
    exit 1
fi

echo "Setting up worktree at $worktree_path..." >&2

# Trust mise
if [ -f "$worktree_path/.tool-versions" ] || [ -d "$worktree_path/mise" ] || [ -f "$worktree_path/mise.toml" ] || [ -f "$worktree_path/.mise.toml" ]; then
    echo "Found mise configuration, running mise trust..." >&2
    (cd "$worktree_path" && mise trust) >&2
fi

# Install JS dependencies if package.json exists (quietly; errors still show)
if [ -f "$worktree_path/package.json" ]; then
    if [ -f "$worktree_path/bun.lockb" ] || [ -f "$worktree_path/bun.lock" ]; then
        echo "Found bun lock file, running bun install --silent..." >&2
        (cd "$worktree_path" && bun install --silent) >&2 || echo "bun install failed, continuing..." >&2
    else
        echo "Found package.json, running npm ci --silent..." >&2
        (cd "$worktree_path" && npm ci --silent) >&2 || echo "npm ci failed, continuing..." >&2
    fi
fi

if [ -f "$worktree_path/go.mod" ]; then
    echo "Found go.mod, running go mod download" >&2
    (cd "$worktree_path" && go mod download) >&2 || echo "go mod download failed, continuing..." >&2
fi

# Set up remote tracking if not already configured
branch=$(cd "$worktree_path" && git branch --show-current)
if [ -n "$branch" ]; then
    upstream=$(cd "$worktree_path" && git config "branch.$branch.remote" 2>/dev/null)
    if [ -z "$upstream" ]; then
        if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            (cd "$worktree_path" && git branch --set-upstream-to="origin/$branch" "$branch") >&2
            echo "Set upstream to origin/$branch" >&2
        fi
    fi
fi

echo "Worktree setup complete!" >&2

# Machine-readable result — see I/O CONTRACT at top of file.
echo "$worktree_path"
