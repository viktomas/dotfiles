set fish_greeting # Turn off greeting

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
set --export --prepend PATH "/Users/tomas/.rd/bin"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Be careful not tu put anything that is required in scripts to this section
# E.g. sourcing the asdf above needs to be in the non-interactive part because otherwise ASDF is missing in the $PATH
if status is-interactive
    fish_vi_key_bindings # vi insert mode

    # ctrl+alt+G will show FZF with git log (the derault ctrl+alt+l) conflicts with skhd (yabai window operations)
    fzf_configure_bindings --git_log=\e\a


    bind -M insert \cf accept-autosuggestion
    bind -M default gcc "fish_commandline_prepend '#'"
    bind -M insert \c_ "fish_commandline_prepend '#'"

    # init zoxide
    complete -e j
    if command -sq zoxide
        zoxide init --cmd j fish | source
    else
        echo 'zoxide: command not found, please install it from https://github.com/ajeetdsouza/zoxide'
    end

    atuin init fish | source

    if type -q brew

        if test -d (brew --prefix)"/share/fish/completions"
            set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/completions
        end

        if test -d (brew --prefix)"/share/fish/vendor_completions.d"
            set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
        end
    end
end

# uv
fish_add_path "/Users/tomas/.local/bin"
