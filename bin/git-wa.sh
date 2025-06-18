#!/bin/bash

# Execute git worktree with all passed arguments and
# Check if git worktree command was successful
if git worktree add "$@"; then
    # Get the last argument as the worktree path
    for last; do true; done
    worktree_path="$last"
    
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
            (cd "$worktree_path" && npm ci)
        fi

        
        # Copy files from parent directory
        echo "Copying additional files..."
        for item in "CLAUDE.md" ".claude"; do
            if [ -e "$item" ]; then
                cp -r "$item" "$worktree_path/"
                echo "Copied $item"
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
