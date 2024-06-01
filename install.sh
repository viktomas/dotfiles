#!/bin/bash
LOCATION="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
ln -s $LOCATION/.ignore ~/.ignore
ln -s $LOCATION/.crontab ~/.crontab
ln -s $LOCATION/.githelpers ~/.githelpers
ln -s $LOCATION/.gitconfig ~/.gitconfig
ln -s $LOCATION/.gitconfig-work ~/.gitconfig-work
ln -s $LOCATION/.gitconfig-private ~/.gitconfig-private
ln -s $LOCATION/.profile ~/.profile
ln -s $LOCATION/.ag-ignore ~/.ag-ignore
ln -s $LOCATION/bin/ ~/
ln -s $LOCATION/.global-gitignore ~/.gitignore
ln -s $LOCATION/.goduignore ~/.goduignore
ln -s $LOCATION/.yamllint.yaml ~/.yamllint.yaml
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/espanso/base.yml" "$HOME/Library/Application Support/espanso/match/base.yml"
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code - Insiders/User/settings.json"
[ "$(uname 2>/dev/null)" == "Linux" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/.config/Code - OSS/User/settings.json"
cd ~/.dotfiles
stow kitty
stow fish
stow fd
stow helix
stow yamlfmt
stow zellij

# tiling window manager
stow yabai
stow skhd

### NeoVim
stow nvim
# Create files for vim backup/undo
mkdir -p ~/.vim/swap ~/.vim/backup ~/.vim/undo
chmod 700 ~/.vim ~/.vim/backup/ ~/.vim/undo/ ~/.vim/swap/ # sensitive information might be in vim tmp files

[ "$(uname 2>/dev/null)" == "Darwin" ] && stow karabiner

[[ $SHELL != *"fish" ]] && chsh -s $(which fish)

[ ! -d ~/.asdf ] && git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
