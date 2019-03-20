#!/bin/sh
LOCATION=`pwd`
ln -s $LOCATION/.bashrc ~/.bashrc
ln -s $LOCATION/.ignore ~/.ignore
ln -s $LOCATION/.gitconfig ~/.gitconfig
ln -s $LOCATION/.githelpers ~/.githelpers
ln -s $LOCATION/.i3 ~/.i3
ln -s $LOCATION/.profile ~/.profile
ln -s $LOCATION/vim ~/.config/nvim
ln -s $LOCATION/.zshrc ~/.zshrc
ln -s $LOCATION/.ag-ignore ~/.ag-ignore
ln -s $LOCATION/.credorc ~/.credorc
ln -s $LOCATION/bin ~/bin
ln -s $LOCATION/tmux-cheat-sheet.txt ~/tmux.cheat
ln -s $LOCATION/.nvpy.cfg ~/.nvpy.cfg

sudo apt-get install silversearcher-ag fzf
