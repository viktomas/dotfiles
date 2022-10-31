#!/bin/bash
LOCATION="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
ln -s $LOCATION/.ignore ~/.ignore
ln -s $LOCATION/.crontab ~/.crontab
ln -s $LOCATION/.githelpers ~/.githelpers
ln -s $LOCATION/.gitconfig ~/.gitconfig
ln -s $LOCATION/.gitconfig-work ~/.gitconfig-work
ln -s $LOCATION/.gitconfig-private ~/.gitconfig-private
ln -s $LOCATION/.profile ~/.profile
ln -s $LOCATION/vim ~/.config/nvim
# Create files for vim backup/undo
mkdir -p ~/.vim/swap ~/.vim/backup ~/.vim/undo
ln -s $LOCATION/.ag-ignore ~/.ag-ignore
ln -s $LOCATION/bin/ ~/
ln -s $LOCATION/.global-gitignore ~/.gitignore
ln -s $LOCATION/.goduignore ~/.goduignore
ln -s $LOCATION/.notable.json ~/.notable.json
[ "$(uname 2> /dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
[ "$(uname 2> /dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code - Insiders/User/settings.json"
[ "$(uname 2> /dev/null)" == "Linux" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/.config/Code - OSS/User/settings.json"
cd ~/.dotfiles
stow kitty
stow fish
stow fd

[ "$(uname 2> /dev/null)" == "Darwin" ] && stow karabiner
git config --global core.excludesfile '~/.gitignore' 
