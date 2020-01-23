
# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

export PATH="$PATH:$HOME/.rbenv/bin" # Add rbenv to PATH for scripting
eval "$(rbenv init -)"

# dependency of git-flow-avh
export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"

# sourcing .profile file
if [[ -s ~/workspace/scripts/lazy_profile.zsh ]]; then
  source ~/workspace/scripts/lazy_profile.zsh
fi

source ~/.profile

# VIM zshell
bindkey -v #switch to vim mode
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
#alias httpserver="python -m SimpleHTTPServer"
alias httpserver="python -m http.server"
  

alias j9="export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-9.jdk/Contents/Home/"
alias j8="export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_144.jdk/Contents/Home/"
alias j7="export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home"

alias custaws-describe-autoscaling=aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[] | "\(.AutoScalingGroupName) - \(.MinSize) - \(.DesiredCapacity)"'

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
fi
 
if [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
  # Do something under GNU/Linux platform
  xinput --set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Profile Enabled' 0, 1
  xinput --set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Speed' 1
  # The next line updates PATH for the Google Cloud SDK.
  [ -f '/home/tomas/Downloads/google-cloud-sdk/path.zsh.inc' ] && '/home/tomas/Downloads/google-cloud-sdk/path.zsh.inc'
  # The next line enables shell command completion for gcloud.
  [ -f '/home/tomas/Downloads/google-cloud-sdk/completion.zsh.inc' ] && source '/home/tomas/Downloads/google-cloud-sdk/completion.zsh.inc'
fi

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"


# omg mac, what are you doing to me
alias fix-spotlight='find . -type d -name "node_modules" -exec touch "{}/.metadata_never_index" \;'

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

