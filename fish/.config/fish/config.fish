source ~/.secrets/secrets
if status is-interactive
    fish_vi_key_bindings

    function fish_user_key_bindings
        bind --mode insert \cr fzf_history_search
        bind --mode insert \cf forward-char
        bind --mode default gcc "fish_commandline_prepend '#'"
        bind --mode insert \c_ "fish_commandline_prepend '#'"
        bind --mode insert ctrl-alt-l fzf_git_log
        bind --mode insert ctrl-alt-p fzf_process_search
        bind --mode insert ctrl-alt-f fzf_file
        bind --mode insert \cx zummoner
    end

    zoxide init fish --no-cmd | source
    mise activate fish | source
    direnv hook fish | source

    function zellij_tab_name_update --on-event fish_preexec
        if set -q ZELLIJ
            set title (string split ' ' $argv)[1]
            command nohup zellij action rename-tab $title >/dev/null 2>&1
        end
    end

end

# Added by GDK bootstrap
/opt/homebrew/bin/mise activate fish | source

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tomas/google-cloud-sdk/path.fish.inc' ]
    . '/Users/tomas/google-cloud-sdk/path.fish.inc'
end
