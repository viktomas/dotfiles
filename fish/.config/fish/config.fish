set fish_greeting # Turn off greeting
fish_vi_key_bindings # vi insert mode

source ~/.profile

function fish_user_key_bindings
    for mode in insert default visual
        bind -M $mode \cf forward-char
    end
end
if test (uname) = "Darwin"
     alias code=code-insiders
else 
end
