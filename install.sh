#!/bin/bash
LOCATION="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
ln -s $LOCATION/.ignore ~/.ignore
ln -s $LOCATION/.githelpers ~/.githelpers
ln -s $LOCATION/.profile ~/.profile
ln -s $LOCATION/vim ~/.config/nvim
ln -s $LOCATION/.zshrc ~/.zshrc
[ "$(uname 2> /dev/null)" == "Linux" ] && ln -s $LOCATION/.zshrc-Linux ~/.zshrc-Linux
[ "$(uname 2> /dev/null)" == "Darwin" ] && ln -s $LOCATION/.zshrc-Darwin ~/.zshrc-Darwin
ln -s $LOCATION/.ag-ignore ~/.ag-ignore
ln -s $LOCATION/.credorc ~/.credorc
ln -s $LOCATION/bin/ ~/
ln -s $LOCATION/.global-gitignore ~/.gitignore
ln -s $LOCATION/.taskbook.json ~/.taskbook.json
ln -s $LOCATION/.goduignore ~/.goduignore
ln -s $LOCATION/.notable.json ~/.notable.json
[ "$(uname 2> /dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
[ "$(uname 2> /dev/null)" == "Linux" ] && ln -s "$LOCATION/vscode/settings.json" "/home/tomas/.config/Code - OSS/User/settings.json"
ln -s ~/Dropbox/.gitconfig ~/.gitconfig
cd ~/.dotfiles
stow kitty
stow ranger
stow fish

[ "$(uname 2> /dev/null)" == "Darwin" ] && stow karabiner
git config --global core.excludesfile '~/.gitignore' 
