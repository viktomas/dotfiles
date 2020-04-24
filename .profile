
export PATH="$PATH:$HOME/workspace/bin" # Add workspace bin to the path

export GOPATH="$HOME/workspace/go"

export PATH="$PATH:$GOPATH/bin"

export GO111MODULE=on

export HISTSIZE=1000000
export HISTFILE=~/.histfile
export SAVEHIST=1000000

export EDITOR=nvim

alias dc=docker-compose
alias gd="godu -print0 | xargs -0 rm -rf"
alias gm="godu -print0 | xargs -0 -I _ mv _ "
alias ts="timer start"
alias tp="timer pause"
alias tas="timer -a start"
alias tr="~/workspace/private/timer/reportAndNotify.sh"


# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

[[ -s "$HOME/.gitter-shortcuts" ]] && source "$HOME/.gitter-shortcuts"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
