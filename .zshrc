
# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# sourcing .profile file
if [[ -s ~/workspace/scripts/lazy_profile.zsh ]]; then
  source ~/workspace/scripts/lazy_profile.zsh
fi
 
source ~/.profile

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
if [[ -s /usr/local/opt/nvm/nvm.sh ]]; then
  . "/usr/local/opt/nvm/nvm.sh"
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#don't bother me with the rm confirmation
setopt rmstarsilent
setopt clobber

# function powerline_precmd() {
#     PS1="$(~/workspace/go/bin/powerline-go -error $?\
#       -shell zsh\
#       -modules cwd,docker,exit,git,jobs,root,ssh,keymap\
#       -priority cwd,docker,exit,git,jobs,root,ssh,keymap)"
# }

# function install_powerline_precmd() {
#   for s in "${precmd_functions[@]}"; do
#     if [ "$s" = "powerline_precmd" ]; then
#       return
#     fi
#   done
#   precmd_functions+=(powerline_precmd)
# }

# if [ "$TERM" != "linux" ]; then
#     install_powerline_precmd
# fi

# function zle-line-init zle-keymap-select {
#     export KEYMAP_POWERLINE=$KEYMAP
#     powerline_precmd
#     zle reset-prompt
# }

# zle -N zle-line-init
# zle -N zle-keymap-select

alias vpn='~/workspace/dotfiles/bin/vpn'
alias vpnls='~/workspace/dotfiles/bin/vpnls'

alias ag='ag --path-to-ignore ~/.ignore'
export FZF_DEFAULT_COMMAND='ag --path-to-ignore ~/.ignore -g ""'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/tomas/Downloads/google-cloud-sdk/path.zsh.inc' ]; then source '/home/tomas/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/tomas/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then source '/home/tomas/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
