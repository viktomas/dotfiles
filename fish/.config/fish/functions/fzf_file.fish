function fzf_file
    set -l initial_query (commandline -b)

    fd | fzf \
        --query "$initial_query" \
        # --no-sort \
        # --bind=ctrl-r:toggle-sort \
        --highlight-line \
        --tiebreak=index \
        # --scheme=history \
        | read -l file

    if test -n "$file"
        commandline -i "\"$file\""
    end
end
