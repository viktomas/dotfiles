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

# Extract project path from MR URL
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

# Normalize and compare
mr_project_normalized=$(echo "$mr_project" | sed 's|\.git$||')
origin_project_normalized=$(echo "$origin_project" | sed 's|\.git$||')

if [[ "$mr_project_normalized" != "$origin_project_normalized" ]] && \
   [[ "$mr_project_normalized" != *"$origin_project_normalized" ]] && \
   [[ "$origin_project_normalized" != *"$mr_project_normalized" ]]; then
    echo "Error: MR is from different project!" >&2
    echo "  MR project: $mr_project_normalized" >&2
    echo "  Origin project: $origin_project_normalized" >&2
    exit 1
fi

echo "✓ Verified MR is from correct project: $origin_project_normalized" >&2

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

if [ -z "$branch_name" ]; then
    echo "Error: Could not get source branch name from glab" >&2
    exit 1
fi

if [ -z "$target_branch" ]; then
    echo "Error: Could not get target branch name from glab" >&2
    exit 1
fi

echo "Source branch: $branch_name" >&2
echo "Target branch: $target_branch" >&2

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

# Worktree folder: replace / with - in branch name
worktree_folder=$(echo "$branch_name" | tr '/' '-')
worktree_path="$project_root/$worktree_folder"

if [ -d "$worktree_path" ]; then
    echo "✓ Worktree already exists: $worktree_path" >&2
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

# Output for callers (stdout)
echo "$worktree_path"
echo "$target_branch"
