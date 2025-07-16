# use G_FOLDER_ALIASES as the configuration variable
# set with `set -Ux G_FOLDER_ALIASES "e:/Users/tomas/workspace/gl/gitlab-vscode-extension,l:/Users/tomas/workspace/gl/gitlab-lsp"`
# append with `set -Ux G_FOLDER_ALIASES "$G_FOLDER_ALIASES,w:/home/user/work"`

function g
    # Check if alias argument is provided
    if test (count $argv) -eq 0
        echo "Usage: g <alias> [folder]"
        return 1
    end

    set alias $argv[1]

    # Parse G_FOLDER_ALIASES (format: "alias1:/path1,alias2:/path2")
    set folder_path ""
    for pair in (string split "," $G_FOLDER_ALIASES)
        set parts (string split ":" $pair)
        if test "$parts[1]" = "$alias"
            set folder_path $parts[2]
            break
        end
    end

    # Check if alias exists
    if test -z "$folder_path"
        echo "Alias '$alias' not found in G_FOLDER_ALIASES"
        return 1
    end

    # If folder argument provided, cd directly
    if test (count $argv) -gt 1
        set target_folder "$folder_path/$argv[2]"
        if test -d "$target_folder"
            cd "$target_folder"
        else
            echo "Folder not found: $target_folder"
            return 1
        end
        return 0
    end

    # No folder specified, use fzf to select
    if not command -v fzf >/dev/null
        echo "fzf is required but not installed"
        return 1
    end

    # Find folders and let user select with fzf
    set selected_folder (find "$folder_path" -maxdepth 1 -type d ! -path "$folder_path" -exec basename {} \; | fzf --prompt="Select folder in $alias: ")

    if test -n "$selected_folder"
        # Replace current command line with the selected folder and execute
        commandline "g $alias $selected_folder"
        commandline -f execute
    end
end
