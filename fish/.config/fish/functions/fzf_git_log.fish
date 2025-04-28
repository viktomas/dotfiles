function fzf_git_log
    git log --oneline --decorate --color=always | fzf \
        --ansi \
        --no-sort \
        --highlight-line \
        --prompt="Git Log> " \
        --preview 'git show --color=always {1}' \
        --scheme=history \
        | read -l selected_commit
    if test -n "$selected_commit"
        set -l commit_hash (echo $selected_commit | awk '{print $1}')
        set -l full_hash (git rev-parse $commit_hash)
        commandline -i $full_hash
    end
end
