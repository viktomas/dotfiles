set fish_greeting # Turn off greeting
fish_vi_key_bindings # vi insert mode

source ~/.profile

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \cf forward-char
    end
end

alias code=code-insiders

# Source autojump
[ -e /usr/share/autojump/autojump.fish ]; and source /usr/share/autojump/autojump.fish
[ -e /usr/local/share/autojump/autojump.fish ]; and source /usr/local/share/autojump/autojump.fish
[ -e /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish
[ -e (brew --prefix asdf)/asdf.fish ]; and source (brew --prefix asdf)/asdf.fish
