#!/bin/bash
#
# Wrapper around `git worktree add` that also runs post-create setup
# (mise trust, npm ci, go mod download) and cd's into the new worktree.
#
# ─── I/O NOTE FOR CALLERS ───────────────────────────────────────────────────
# This script writes human-facing progress messages to STDOUT (and forwards
# `git worktree add` output to stderr). It is NOT a machine-readable
# producer — there is no stdout contract.
#
# If you invoke it from another script that DOES have a stdout contract
# (e.g. git-mr-worktree.sh), redirect this script's stdout to stderr:
#     ~/bin/git-wa.sh <path> <branch> >&2
# Otherwise its progress lines will pollute your captured output.
# ──────────────────────────────────────────────────────────────────────────

if git worktree add "$@" 1>&2; then
# The first argument is always the worktree path for git worktree add
    worktree_path=$(cd "$1" && pwd)

    # Check if worktree path exists and is a directory
    if [ -d "$worktree_path" ]; then
        echo "Setting up worktree at $worktree_path..."

        # Trust mise
        if [ -f "$worktree_path/.tool-versions" ] || [ -d "$worktree_path/mise" ] || [ -f "$worktree_path/mise.toml" ] || [ -f "$worktree_path/.mise.toml" ]; then
            echo "Found mise configuration, running mise trust..."
            (cd "$worktree_path" && mise trust)
        fi

        # Install JS dependencies if package.json exists
        if [ -f "$worktree_path/package.json" ]; then
            if [ -f "$worktree_path/bun.lockb" ] || [ -f "$worktree_path/bun.lock" ]; then
                echo "Found bun lock file, running bun install..."
                (cd "$worktree_path" && bun install) || echo "bun install failed, continuing..."
            else
                echo "Found package.json, running npm ci..."
                (cd "$worktree_path" && npm ci) || echo "npm ci failed, continuing..."
            fi
        fi

        if [ -f "$worktree_path/go.mod" ]; then
            echo "Found go.mod, running go mod download"
            (cd "$worktree_path" && go mod download) || echo "go mod download failed, continuing..."
        fi

        # Set up remote tracking if not already configured
        branch=$(cd "$worktree_path" && git branch --show-current)
        if [ -n "$branch" ]; then
            upstream=$(cd "$worktree_path" && git config "branch.$branch.remote" 2>/dev/null)
            if [ -z "$upstream" ]; then
                if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
                    (cd "$worktree_path" && git branch --set-upstream-to="origin/$branch" "$branch")
                    echo "Set upstream to origin/$branch"
                fi
            fi
        fi

        ## change dir to the new worktree
        cd "$worktree_path" || exit 1
        echo "Worktree setup complete!"
    else
        echo "Error: Could not find worktree directory $worktree_path"
    fi
else
    echo "git worktree command failed"
    exit 1
fi
