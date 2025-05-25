function fzf_process_search
    ps aux | tail -n +2 | fzf \
        --ansi \
        --no-sort \
        --highlight-line \
        --prompt="Process> " \
        --preview 'echo "PID: {2}\nCommand: {11..}\nCPU: {3}%\nMemory: {4}%\nUser: {1}"' \
        --preview-window=up:5 \
        --header="USER PID %CPU %MEM COMMAND" \
        --scheme=history \
        | read -l selected_process
    if test -n "$selected_process"
        set -l pid (echo $selected_process | awk '{print $2}')
        commandline -i $pid
    end
end
