source ~/.secrets
if status is-interactive
    ,countdown
    fish_vi_key_bindings

    function fish_user_key_bindings
        bind --mode insert \cr fzf_history_search
        bind --mode insert \cf forward-char
        bind --mode insert ctrl-alt-l fzf_git_log
        bind --mode insert ctrl-alt-p fzf_process_search
        bind --mode insert ctrl-alt-f fzf_file
        bind --mode insert \cx zummoner
    end

    zoxide init fish --no-cmd | source
    mise activate fish | source
    direnv hook fish | source

end

# Added by GDK bootstrap
/opt/homebrew/bin/mise activate fish | source
