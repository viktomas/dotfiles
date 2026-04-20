#!/usr/bin/env bash
set -e

# Creates (or finds) a worktree for a GitLab MR URL.
# Outputs two lines to stdout:
#   1. worktree path
#   2. target branch
# All progress/status messages go to stderr.

if [ -z "$1" ]; then
    echo "Usage: git-mr-worktree.sh <gitlab-merge-request-url>" >&2
    exit 1
fi

url="$1"

# Extract project path from MR URL (this is the target/destination project)
mr_project=$(echo "$url" | sed -E 's|https?://[^/]+/(.*)/-/merge_requests/.*|\1|')
if [ -z "$mr_project" ]; then
    echo "Error: Could not parse project from URL: $url" >&2
    exit 1
fi

# Get git remote origin
origin_url=$(git remote get-url origin)
if [ -z "$origin_url" ]; then
    echo "Error: Could not get git remote origin" >&2
    exit 1
fi

# Extract project path from origin URL (SSH or HTTPS)
origin_project=$(echo "$origin_url" | sed -E 's|.*[:/](.+)(\.git)?$|\1|' | sed 's|\.git$||')
if [ -z "$origin_project" ]; then
    echo "Error: Could not parse project from origin URL: $origin_url" >&2
    exit 1
fi

# Normalize and compare: the MR's TARGET project must match origin.
# (The MR's SOURCE project may differ when it's from a fork — handled below.)
mr_project_normalized=$(echo "$mr_project" | sed 's|\.git$||')
origin_project_normalized=$(echo "$origin_project" | sed 's|\.git$||')

if [[ "$mr_project_normalized" != "$origin_project_normalized" ]] && \
   [[ "$mr_project_normalized" != *"$origin_project_normalized" ]] && \
   [[ "$origin_project_normalized" != *"$mr_project_normalized" ]]; then
    echo "Error: MR targets a different project than origin!" >&2
    echo "  MR target project: $mr_project_normalized" >&2
    echo "  Origin project:    $origin_project_normalized" >&2
    exit 1
fi

echo "✓ Verified MR targets origin project: $origin_project_normalized" >&2

# Extract MR number
mr_number=$(echo "$url" | sed -E 's|.*/merge_requests/([0-9]+).*|\1|')
if [ -z "$mr_number" ]; then
    echo "Error: Could not extract MR number from URL" >&2
    exit 1
fi

echo "MR number: $mr_number" >&2

# Get MR info via glab
echo "Fetching MR details with glab..." >&2
mr_info=$(glab mr view "$mr_number" --output json)

branch_name=$(echo "$mr_info" | jq -r '.source_branch')
target_branch=$(echo "$mr_info" | jq -r '.target_branch')
source_project_id=$(echo "$mr_info" | jq -r '.source_project_id')
target_project_id=$(echo "$mr_info" | jq -r '.target_project_id')

if [ -z "$branch_name" ] || [ "$branch_name" = "null" ]; then
    echo "Error: Could not get source branch name from glab" >&2
    exit 1
fi

if [ -z "$target_branch" ] || [ "$target_branch" = "null" ]; then
    echo "Error: Could not get target branch name from glab" >&2
    exit 1
fi

echo "Source branch: $branch_name" >&2
echo "Target branch: $target_branch" >&2

# Detect fork MR: source project ID differs from target project ID
is_fork=0
fork_remote=""
local_branch="$branch_name"
if [ -n "$source_project_id" ] && [ "$source_project_id" != "null" ] && \
   [ -n "$target_project_id" ] && [ "$target_project_id" != "null" ] && \
   [ "$source_project_id" != "$target_project_id" ]; then
    is_fork=1
    echo "MR is from a fork (source_project_id=$source_project_id, target_project_id=$target_project_id)" >&2
    echo "Fetching fork project details..." >&2
    fork_info=$(glab api "projects/$source_project_id")
    fork_path=$(echo "$fork_info" | jq -r '.path_with_namespace')
    fork_ssh_url=$(echo "$fork_info" | jq -r '.ssh_url_to_repo')
    if [ -z "$fork_path" ] || [ "$fork_path" = "null" ] || [ -z "$fork_ssh_url" ] || [ "$fork_ssh_url" = "null" ]; then
        echo "Error: Could not resolve fork project $source_project_id" >&2
        exit 1
    fi
    echo "Fork project: $fork_path" >&2

    # Remote name = first path segment (fork owner/namespace), sanitized.
    # Use printf (no trailing newline) so tr doesn't turn it into a stray char.
    fork_owner=$(printf '%s' "$fork_path" | cut -d'/' -f1)
    fork_remote=$(printf '%s' "$fork_owner" | tr -c 'A-Za-z0-9._-' '-')
    # Local branch name: prefix with 'fork/' so it can't collide with the
    # remote-tracking ref 'refs/remotes/<fork_remote>/<branch_name>'.
    local_branch="fork/$fork_remote/$branch_name"
fi

# Find project root (.bare parent)
git_dir=$(git rev-parse --git-dir)
current_dir=$(pwd)

if [[ "$git_dir" == *".bare"* ]]; then
    project_root=$(echo "$git_dir" | sed -E 's|(.*)/\.bare.*|\1|')
else
    temp_dir="$current_dir"
    while [ "$temp_dir" != "/" ]; do
        if [ -d "$temp_dir/.bare" ]; then
            project_root="$temp_dir"
            break
        fi
        temp_dir=$(dirname "$temp_dir")
    done

    if [ -z "$project_root" ]; then
        echo "Error: Could not find .bare directory in project structure" >&2
        exit 1
    fi
fi

echo "Project root: $project_root" >&2

# Navigate to .bare directory
cd "$project_root/.bare"

# Worktree folder: replace / with - in local branch name
worktree_folder=$(echo "$local_branch" | tr '/' '-')
worktree_path="$project_root/$worktree_folder"

if [ -d "$worktree_path" ]; then
    echo "✓ Worktree already exists: $worktree_path" >&2
else
    if [ "$is_fork" = "1" ]; then
        # Add the fork as a remote if not already present
        if ! git remote get-url "$fork_remote" >/dev/null 2>&1; then
            echo "Adding remote '$fork_remote' -> $fork_ssh_url" >&2
            git remote add "$fork_remote" "$fork_ssh_url"
        else
            existing_url=$(git remote get-url "$fork_remote")
            echo "Remote '$fork_remote' already exists: $existing_url" >&2
        fi

        echo "Fetching $fork_remote/$branch_name..." >&2
        git fetch "$fork_remote" "$branch_name"

        # Create the local branch if it doesn't already exist
        if ! git show-ref --verify --quiet "refs/heads/$local_branch"; then
            echo "Creating local branch $local_branch tracking $fork_remote/$branch_name" >&2
            git branch --track "$local_branch" "$fork_remote/$branch_name"
        fi

        echo "Creating worktree for fork branch: $local_branch" >&2
        if ~/bin/git-wa.sh "$worktree_path" "$local_branch"; then
            echo "✓ Created worktree: $worktree_path" >&2
        else
            echo "Error: Failed to create worktree" >&2
            exit 1
        fi
    else
        echo "Creating worktree for branch: $branch_name" >&2
        git fetch origin "$branch_name:$branch_name" 2>/dev/null || git fetch origin

        if ~/bin/git-wa.sh "$worktree_path" "$branch_name"; then
            echo "✓ Created worktree: $worktree_path" >&2
        else
            echo "Error: Failed to create worktree" >&2
            exit 1
        fi
    fi
fi

# Output for callers (stdout)
echo "$worktree_path"
echo "$target_branch"
