#!/bin/sh
LOCATION=$(dirname "$0")
ln -s $LOCATION/.ignore ~/.ignore
ln -s $LOCATION/.gitconfig ~/.gitconfig
ln -s $LOCATION/.githelpers ~/.githelpers
ln -s $LOCATION/.profile ~/.profile
ln -s $LOCATION/vim ~/.config/nvim
ln -s $LOCATION/.zshrc ~/.zshrc
ln -s $LOCATION/.ag-ignore ~/.ag-ignore
ln -s $LOCATION/.credorc ~/.credorc
ln -s $LOCATION/bin/ ~/
ln -s $LOCATION/tmux-cheat-sheet.txt ~/tmux.cheat
ln -s $LOCATION/.nvpy.cfg ~/.nvpy.cfg
ln -s $LOCATION/.global-gitignore ~/.gitignore
ln -s $LOCATION/.taskbook.json ~/.taskbook.json
ln -s $LOCATION/.goduignore ~/.goduignore

git config --global core.excludesfile '~/.gitignore' 
