#!/bin/bash
# Debug environment differences
# echo "=== DEBUG INFO ===" >&2
# echo "Script path: $0" >&2
# echo "Working directory: $(pwd)" >&2
# echo "PATH: $PATH" >&2
# echo "Git root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'Not in git repo')" >&2
# echo "Git dir: $(git rev-parse --git-dir 2>/dev/null || echo 'Not in git repo')" >&2
# echo "Arguments: $@" >&2
# echo "Number of args: $#" >&2
# echo "Shell: $SHELL" >&2
# echo "User: $USER" >&2
# echo "==================" >&2
# worktree_path=$(cd "$1" && pwd)
# (cd "$worktree_path" && npm run prepare)
# # Execute git worktree with all passed arguments and
# # Check if git worktree command was successful
if git worktree add "$@"; then
# The first argument is always the worktree path for git worktree add
    worktree_path=$(cd "$1" && pwd)

    # Check if worktree path exists and is a directory
    if [ -d "$worktree_path" ]; then
        echo "Setting up worktree at $worktree_path..."

        # Trust mise
        if [ -f "$worktree_path/.tool-versions" ] || [ -d "$worktree_path/mise" ]; then
            echo "Found mise configuration, running mise trust..."
            (cd "$worktree_path" && mise trust)
        fi

        # Install npm dependencies if package.json exists
        if [ -f "$worktree_path/package.json" ]; then
            echo "Found package.json, running npm install..."
            (cd "$worktree_path" && npm ci) || echo "npm ci failed, continuing..."
        fi

        # Create soft links for files from parent directory
        echo "Creating soft links for additional files..."
        for item in "CLAUDE.md" ".claude"; do
            if [ -e "$item" ]; then
                # Get absolute path of the source item
                source_path=$(realpath "$item")
                target_path="$worktree_path/$item"

                # Remove existing file/directory if it exists
                if [ -e "$target_path" ]; then
                    rm -rf "$target_path"
                fi

                # Create soft link
                ln -s "$source_path" "$target_path"
                echo "Created soft link for $item"
            else
                echo "Warning: $item not found in parent directory"
            fi
        done

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
