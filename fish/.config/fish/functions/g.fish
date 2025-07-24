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
    set folder_path (__g_get_alias_path $alias)

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

    # No folder specified, cd to the base path
    cd "$folder_path"
end
