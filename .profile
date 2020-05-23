export PATH="$PATH:$HOME/workspace/bin" # Add workspace bin to the path

export GOPATH="$HOME/workspace/go"

export PATH="$PATH:$HOME/.rvm/bin"

# dependency of git-flow-avh
export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

export PATH="$PATH:$GOPATH/bin"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk.jdk/Contents/Home"

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
alias cat="bat"
alias diff="diff-so-fancy"
alias ls="exa"
alias find="fd"
alias la="ls -laF"


# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

[[ -s "$HOME/.gitter-shortcuts" ]] && source "$HOME/.gitter-shortcuts"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
