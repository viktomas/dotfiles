#!/bin/bash
LOCATION="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
ln -s $LOCATION/.ignore ~/.ignore
ln -s $LOCATION/.githelpers ~/.githelpers
ln -s $LOCATION/.profile ~/.profile
ln -s $LOCATION/vim ~/.config/nvim
ln -s $LOCATION/.zshrc ~/.zshrc
ln -s $LOCATION/.ag-ignore ~/.ag-ignore
ln -s $LOCATION/.credorc ~/.credorc
ln -s $LOCATION/bin/ ~/
ln -s $LOCATION/.global-gitignore ~/.gitignore
ln -s $LOCATION/.taskbook.json ~/.taskbook.json
ln -s $LOCATION/.goduignore ~/.goduignore
ln -s $LOCATION/.notable.json ~/.notable.json
ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
ln -s ~/Dropbox/.gitconfig ~/.gitconfig
cd ~/.dotfiles
stow kitty

git config --global core.excludesfile '~/.gitignore' 
