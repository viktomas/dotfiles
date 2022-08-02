export GOPATH="$HOME/workspace/go"

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

export PATH="$PATH:$GOPATH/bin"

export EDITOR=nvim
export VISUAL=$EDITOR
export HOMEBREW_PREFIX=/opt/homebrew
export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.ignore -g ""'

alias gd="godu -print0 | xargs -0 rm -rf"
alias gm="godu -print0 | xargs -0 -I _ mv _ "

