export GOPATH="$HOME/workspace/go"

export PATH="$PATH:$HOME/.rvm/bin"

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

export PATH="$PATH:$GOPATH/bin"

export HISTSIZE=1000000
export HISTFILE=~/.histfile
export SAVEHIST=1000000

export EDITOR=nvim
export VISUAL=$EDITOR
export BROWSER=firefox-developer-edition

alias vim=nvim
alias gd="godu -print0 | xargs -0 rm -rf"
alias gm="godu -print0 | xargs -0 -I _ mv _ "
alias ts="timer start"
alias tp="timer pause"
alias tas="timer start -a"
alias tr="timer report"
alias diff="diff-so-fancy"
alias icat="kitty +kitten icat"
alias cal="cal --monday"
alias vpn='nordvpn'
alias vpnc='nordvpn connect'

