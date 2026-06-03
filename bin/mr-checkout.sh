#!/usr/bin/env bash
set -euo pipefail

# mr-checkout.sh — Checks out an MR branch locally.
#
# Reads JSON from stdin with fields:
#   mr.source_branch, mr.target_branch, mr.source_project_id, mr.target_project_id
#   local_dir, is_bare, fork_ssh_url, fork_remote, local_branch
#
# STDOUT: the final worktree/checkout path (machine-readable)
# STDERR: all human-facing progress messages

json=$(cat)

# Parse fields
local_dir=$(echo "$json" | jq -r '.local_dir')
is_bare=$(echo "$json" | jq -r '.is_bare')
source_branch=$(echo "$json" | jq -r '.mr.source_branch')
local_branch=$(echo "$json" | jq -r '.local_branch')
fork_ssh_url=$(echo "$json" | jq -r '.fork_ssh_url // empty')
fork_remote=$(echo "$json" | jq -r '.fork_remote // empty')

if [ -z "$local_dir" ] || [ "$local_dir" = "null" ]; then
    echo "error: no local directory resolved for this project" >&2
    exit 1
fi

if [ ! -d "$local_dir" ]; then
    echo "error: local directory does not exist: $local_dir" >&2
    exit 1
fi

echo "Project: $local_dir" >&2
echo "Branch: $local_branch" >&2

# ─── BARE REPO (worktree layout) ──────────────────────────────────────────

if [ "$is_bare" = "true" ]; then
    bare_dir="$local_dir/.bare"

    # Find existing worktree by branch name (not folder name).
    # Worktrees created by `git wta -n <name>` use short folder names
    # that don't match the full branch path.
    worktree_path=""
    while IFS= read -r line; do
        if [[ "$line" == "worktree "* ]]; then
            current_wt="${line#worktree }"
        elif [[ "$line" == "branch refs/heads/$local_branch" ]]; then
            worktree_path="$current_wt"
            break
        fi
    done < <(git -C "$bare_dir" worktree list --porcelain)

    # Fallback: derived folder name
    if [ -z "$worktree_path" ]; then
        worktree_folder=$(echo "$local_branch" | tr '/' '-')
        worktree_path="$local_dir/$worktree_folder"
    fi

    if [ -d "$worktree_path" ]; then
        echo "✓ Worktree already exists: $worktree_path" >&2

        # Check for unstaged changes
        if ! git -C "$worktree_path" diff --quiet 2>/dev/null || \
           ! git -C "$worktree_path" diff --cached --quiet 2>/dev/null; then
            echo "" >&2
            echo "⚠️  Worktree has uncommitted changes:" >&2
            git -C "$worktree_path" diff --stat >&2
            git -C "$worktree_path" diff --cached --stat >&2
            echo "" >&2
            read -r -p "Discard changes and update? [y/N] " answer </dev/tty >&2
            if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
                echo "Keeping existing worktree as-is." >&2
                echo "$worktree_path"
                exit 0
            fi
            git -C "$worktree_path" checkout -- . >&2
            git -C "$worktree_path" clean -fd >&2
        fi

        # Update to latest
        if [ -n "$fork_remote" ] && [ -n "$fork_ssh_url" ]; then
            git -C "$bare_dir" fetch "$fork_remote" "$source_branch" >&2
            git -C "$worktree_path" reset --hard "$fork_remote/$source_branch" >&2
        else
            git -C "$bare_dir" fetch origin "$source_branch" >&2
            git -C "$worktree_path" reset --hard "origin/$source_branch" >&2
        fi
        echo "✓ Updated to latest" >&2
        echo "$worktree_path"
        exit 0
    fi

    # Create new worktree — derive folder name from branch
    worktree_folder=$(echo "$local_branch" | tr '/' '-')
    worktree_path="$local_dir/$worktree_folder"
    cd "$bare_dir"

    if [ -n "$fork_remote" ] && [ -n "$fork_ssh_url" ]; then
        # Fork: add remote if needed, fetch, create branch + worktree
        if ! git remote get-url "$fork_remote" >/dev/null 2>&1; then
            echo "Adding remote '$fork_remote' -> $fork_ssh_url" >&2
            git remote add "$fork_remote" "$fork_ssh_url"
        fi
        echo "Fetching $fork_remote/$source_branch..." >&2
        git fetch "$fork_remote" "$source_branch" >&2

        if ! git show-ref --verify --quiet "refs/heads/$local_branch"; then
            git branch --track "$local_branch" "$fork_remote/$source_branch" >&2
        fi
    else
        echo "Fetching origin/$source_branch..." >&2
        git fetch origin "$source_branch:$source_branch" 2>/dev/null || git fetch origin >&2
    fi

    echo "Creating worktree: $worktree_path" >&2
    if ~/bin/git-wa.sh "$worktree_path" "$local_branch" >&2; then
        echo "✓ Created worktree" >&2

        # Set up tracking for non-fork branches
        if [ -z "$fork_remote" ]; then
            git -C "$worktree_path" branch --set-upstream-to="origin/$source_branch" "$source_branch" 2>/dev/null >&2 || true
        fi
    else
        echo "error: failed to create worktree" >&2
        exit 1
    fi

    echo "$worktree_path"
    exit 0
fi

# ─── NON-BARE REPO (plain git checkout) ──────────────────────────────────

cd "$local_dir"

# Fetch the branch
if [ -n "$fork_remote" ] && [ -n "$fork_ssh_url" ]; then
    if ! git remote get-url "$fork_remote" >/dev/null 2>&1; then
        echo "Adding remote '$fork_remote' -> $fork_ssh_url" >&2
        git remote add "$fork_remote" "$fork_ssh_url"
    fi
    echo "Fetching $fork_remote/$source_branch..." >&2
    git fetch "$fork_remote" "$source_branch" >&2
    fetch_ref="$fork_remote/$source_branch"
else
    echo "Fetching origin/$source_branch..." >&2
    git fetch origin "$source_branch" >&2
    fetch_ref="origin/$source_branch"
fi

current_branch=$(git branch --show-current)

# Already on the right branch?
if [ "$current_branch" = "$local_branch" ]; then
    echo "✓ Already on branch $local_branch" >&2

    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "" >&2
        echo "⚠️  Working tree has uncommitted changes:" >&2
        git diff --stat >&2
        git diff --cached --stat >&2
        echo "" >&2
        read -r -p "Discard changes and update? [y/N] " answer </dev/tty >&2
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "Keeping as-is." >&2
            echo "$local_dir"
            exit 0
        fi
        git checkout -- . >&2
        git clean -fd >&2
    fi

    git reset --hard "$fetch_ref" >&2
    echo "✓ Updated to latest" >&2
    echo "$local_dir"
    exit 0
fi

# Branch exists locally?
if git show-ref --verify --quiet "refs/heads/$local_branch"; then
    echo "Branch $local_branch exists locally" >&2

    # Check current branch for changes before switching
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "" >&2
        echo "⚠️  Current branch ($current_branch) has uncommitted changes:" >&2
        git diff --stat >&2
        echo "" >&2
        echo "Cannot switch branches with uncommitted changes." >&2
        echo "Please commit or stash your changes first." >&2
        exit 1
    fi

    git checkout "$local_branch" >&2
    git reset --hard "$fetch_ref" >&2
    echo "✓ Switched and updated to latest" >&2
    echo "$local_dir"
    exit 0
fi

# Branch doesn't exist — create it
echo "Creating branch $local_branch tracking $fetch_ref" >&2

# Check current branch for changes before switching
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    echo "" >&2
    echo "⚠️  Current branch ($current_branch) has uncommitted changes." >&2
    echo "Cannot switch branches with uncommitted changes." >&2
    echo "Please commit or stash your changes first." >&2
    exit 1
fi

git checkout -b "$local_branch" "$fetch_ref" >&2
echo "✓ Created and checked out $local_branch" >&2
echo "$local_dir"
