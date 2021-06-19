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

# no rm confirmation
setopt rmstarsilent
setopt clobber

export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.ignore -g ""'


source "${ZDOTDIR:-${HOME}}/.zshrc-`uname`"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

# ASDF
source $HOME/.asdf/asdf.sh
# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit
compinit

# Added by GDK bootstrap
export PKG_CONFIG_PATH="/usr/local/opt/icu4c/lib/pkgconfig:${PKG_CONFIG_PATH}"

# Added by GDK bootstrap
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=/usr/local/opt/openssl@1.1 --with-readline-dir=/usr/local/opt/readline"
export PATH="/usr/local/opt/openjdk/bin:$PATH"

