
export PATH="$PATH:$HOME/workspace/bin" # Add workspace bin to the path

export GOPATH="$HOME/workspace/go"

export PATH="$PATH:$GOPATH/bin"

export GO111MODULE=on

export HISTSIZE=1000000
export HISTFILE=~/.histfile
export SAVEHIST=1000000

export EDITOR=nvim

alias dc=docker-compose


# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
