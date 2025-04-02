function fzf_history_search
    set -l initial_query (commandline -b)

    history | fzf \
        --query "$initial_query" \
        --no-sort \
        --bind=ctrl-r:toggle-sort \
        --highlight-line \
        --tiebreak=index \
        --scheme=history \
        | read -l command

    if test -n "$command"
        commandline -f repaint
        commandline -r $command
    end
end
