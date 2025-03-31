if status is-interactive
    fish_vi_key_bindings

    function fish_user_key_bindings
        bind --mode insert \cr fzf_history_search
        bind --mode insert \cf forward-char
    end

    zoxide init fish --no-cmd | source
    mise activate fish | source

    source ~/.secrets
end
