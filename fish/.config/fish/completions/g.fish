####
# Duplicated in the completion file `fish/.config/fish/functions/g.fish`
######

function __g_get_alias_path
    set alias $argv[1]
    for pair in (string split "," $G_FOLDER_ALIASES)
        set parts (string split ":" $pair)
        if test "$parts[1]" = "$alias"
            echo $parts[2]
            return 0
        end
    end
    return 1
end

# Helper function to get all aliases
function __g_get_all_aliases
    for pair in (string split "," $G_FOLDER_ALIASES)
        set parts (string split ":" $pair)
        echo $parts[1]
    end
end

#######
# End of duplication
#######

# Tab completion function for g command
function __g_complete_alias
    # Complete first argument with available aliases
    if test (count (commandline -opc)) -eq 1
        __g_get_all_aliases
    end
end

function __g_complete_folder
    # Complete second argument with folders in the selected alias path
    set cmd (commandline -opc)
    if test (count $cmd) -eq 2
        set alias $cmd[2]
        set folder_path (__g_get_alias_path $alias)

        # List directories in the alias path
        if test -n "$folder_path" -a -d "$folder_path"
            find "$folder_path" -maxdepth 1 -type d ! -path "$folder_path" -exec basename {} \;
        end
    end
end

# Register completions
complete -f -c g -a "(__g_complete_alias)"
complete -f -c g -a "(__g_complete_folder)"
