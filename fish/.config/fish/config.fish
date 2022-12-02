set fish_greeting # Turn off greeting
fish_vi_key_bindings # vi insert mode

source ~/.profile

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \cf forward-char
    end
end

# init zoxide
complete -e j
if command -sq zoxide
    zoxide init --cmd j fish | source
else
    echo 'zoxide: command not found, please install it from https://github.com/ajeetdsouza/zoxide'
end

if type -q brew

    [ -e (brew --prefix asdf)/libexec/asdf.fish ]; and source (brew --prefix asdf)/libexec/asdf.fish

    if test -d (brew --prefix)"/share/fish/completions"
        set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/completions
    end

    if test -d (brew --prefix)"/share/fish/vendor_completions.d"
        set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
    end
end

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
set --export --prepend PATH "/Users/tomas/.rd/bin"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)