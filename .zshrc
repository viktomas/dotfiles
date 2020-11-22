# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi
source ~/.profile

# VIM zshell
bindkey -v #switch to vim mode

export PATH="$PATH:$HOME/.rbenv/bin" # Add rbenv to PATH for scripting

which rbenv > /dev/null && eval "$(rbenv init -)"
which rbenv > /dev/null && eval "$(pyenv init -)"
eval "$(direnv hook zsh)"

export NVM_DIR="$HOME/.nvm"

# no rm confirmation
setopt rmstarsilent
setopt clobber

export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.ignore -g ""'


source "${ZDOTDIR:-${HOME}}/.zshrc-`uname`"

function nvm_use_if_needed_on_cd () {
    [[ -r ./.nvmrc  && -s ./.nvmrc ]] || return
    WANTED=$(sed 's/v//' < ./.nvmrc)
    nvm_use_if_needed $WANTED # this comes from nvm
}
chpwd_functions=(${chpwd_functions[@]} "nvm_use_if_needed_on_cd")