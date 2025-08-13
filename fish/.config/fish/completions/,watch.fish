# THIS IS DUPLICATTED
set -g WATCH_EXTENSION_PATH /Users/tomas/workspace/gl/gitlab-vscode-extension
set -g WATCH_LS_PATH /Users/tomas/workspace/gl/gitlab-lsp

# Shared helper function to get subfolders from a directory
function __watch_get_worktrees
    set repo_path $argv[1]
    if test -d "$repo_path"
        find "$repo_path" -maxdepth 1 -type d ! -path "$repo_path" -exec basename {} \;
    end
end

# Completion for first argument (extension worktree)
function __watch_complete_extension
    if test (count (commandline -opc)) -eq 1
        __watch_get_worktrees $WATCH_EXTENSION_PATH
    end
end

# Completion for second argument (LS worktree)
function __watch_complete_ls
    if test (count (commandline -opc)) -eq 2
        __watch_get_worktrees $WATCH_LS_PATH
    end
end

# Register completions
complete -f -c ",watch" -a "(__watch_complete_extension)"
complete -f -c ",watch" -a "(__watch_complete_ls)"
