#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...

# sourcing .profile file
source ~/.profile

# source credo
if [[ -s ~/.credorc ]]; then
  source ~/.credorc
fi

# VIM zshell
bindkey -v #switch to vim mode
bindkey -M viins 'jj' vi-cmd-mode #binds my favourite vim binding
bindkey -v '\e.' insert-last-word

#commented function for showing vim mode (in osx zshell took forever)
#in prezto prompt works perfectly
#function zle-line-init zle-keymap-select {
#  RPS1="${${KEYMAP/vicmd/-- NORMAL --}/(main|viins)/-- INSERT --}"
#  RPS2=$RPS1
#  zle reset-prompt
#}
#zle -N zle-line-init
#zle -N zle-keymap-select

alias vim=nvim
alias httpserver="python -m SimpleHTTPServer"

  
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
#export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_45.jdk/Contents/Home/
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_79.jdk/Contents/Home

#setup autojump for linux or osx
[[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh
which brew && [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh

function nvm_use_if_needed () {
    [[ -r ./.nvmrc  && -s ./.nvmrc ]] || return
    WANTED=$(sed 's/v//' < ./.nvmrc)
    CURRENT=$(hash node 2>/dev/null && node -v | sed 's/v//')
    if [ "$WANTED" != "$CURRENT" ]; then
        nvm use
    fi
}
chpwd_functions=(${chpwd_functions[@]} "nvm_use_if_needed")

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

#don't bother me with the rm confirmation
setopt rmstarsilent
setopt clobber
