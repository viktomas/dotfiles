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
alias httpserver="python3 -m http.server"
alias dc=docker-compose
alias gd="godu -print0 | xargs -0 rm -rf"
alias gm="godu -print0 | xargs -0 -I _ mv _ "
alias ts="timer start"
alias tp="timer pause"
alias tas="timer start -a"
alias tr="timer report"
alias cat="bat"
alias diff="diff-so-fancy"
alias ls="exa"
alias find="fd"
alias la="ls -laF"
alias icat="kitty +kitten icat"
alias cal="cal --monday"
alias vpn='nordvpn'
alias vpnc='nordvpn connect'
alias ag='ag --path-to-ignore ~/.ignore'

