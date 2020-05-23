# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

export PATH="$PATH:$HOME/.rbenv/bin" # Add rbenv to PATH for scripting
eval "$(rbenv init -)"

source ~/.profile

# VIM zshell
bindkey -v #switch to vim mode

alias vim=nvim
alias httpserver="python3 -m http.server"
eval "$(pyenv init -)"

#setup autojump for linux or osx
[[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh
which brew >> /dev/null && [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh

function nvm_use_if_needed_on_cd () {
    [[ -r ./.nvmrc  && -s ./.nvmrc ]] || return
    WANTED=$(sed 's/v//' < ./.nvmrc)
    nvm_use_if_needed $WANTED # this comes from nvm
}
chpwd_functions=(${chpwd_functions[@]} "nvm_use_if_needed_on_cd")

export NVM_DIR="$HOME/.nvm"
export NVM_INSTALLATION="/usr/local/opt/nvm"
[ -s "$NVM_INSTALLATION/nvm.sh" ] && \. "$NVM_INSTALLATION/nvm.sh"
[ -s "$NVM_INSTALLATION/bash_completion" ] && \. "$NVM_INSTALLATION/bash_completion"  # This loads nvm bash_completion

#don't bother me with the rm confirmation
setopt rmstarsilent
setopt clobber

eval "$(direnv hook zsh)"

alias vpn='nordvpn connect'
alias vpnls='~/workspace/dotfiles/bin/vpnls'

alias ag='ag --path-to-ignore ~/.ignore'
export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.ignore -g ""'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


if [[ "$(uname)" == "Darwin" ]]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  # The next line updates PATH for the Google Cloud SDK.
  [ -f '/Users/tomas/workspace/tools/google-cloud-sdk/path.zsh.inc' ] && . '/Users/tomas/workspace/tools/google-cloud-sdk/path.zsh.inc'
  # The next line enables shell command completion for gcloud.
  [ -f '/Users/tomas/workspace/tools/google-cloud-sdk/completion.zsh.inc' ] && . '/Users/tomas/workspace/tools/google-cloud-sdk/completion.zsh.inc'
else 
  # Do something under GNU/Linux platform
  xinput --set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Profile Enabled' 0, 1
  xinput --set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Speed' 1
  # The next line updates PATH for the Google Cloud SDK.
  [ -f '/home/tomas/Downloads/google-cloud-sdk/path.zsh.inc' ] && '/home/tomas/Downloads/google-cloud-sdk/path.zsh.inc'
  # The next line enables shell command completion for gcloud.
  [ -f '/home/tomas/Downloads/google-cloud-sdk/completion.zsh.inc' ] && source '/home/tomas/Downloads/google-cloud-sdk/completion.zsh.inc'
fi

# omg mac, what are you doing to me
alias fix-spotlight='find . -type d -name "node_modules" -exec touch "{}/.metadata_never_index" \;'

