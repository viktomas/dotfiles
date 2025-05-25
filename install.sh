#!/bin/bash
LOCATION="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
ln -s "$LOCATION/.ignore" ~/.ignore
ln -s "$LOCATION/.crontab" ~/.crontab
ln -s "$LOCATION/.githelpers" ~/.githelpers
ln -s "$LOCATION/.gitconfig" ~/.gitconfig
ln -s "$LOCATION/.gitconfig-work" ~/.gitconfig-work
ln -s "$LOCATION/.gitconfig-private" ~/.gitconfig-private
ln -s "$LOCATION/.profile" ~/.profile
ln -s "$LOCATION/.ag-ignore" ~/.ag-ignore
ln -s "$LOCATION/bin/" ~/
ln -s "$LOCATION/.global-gitignore" ~/.gitignore
ln -s "$LOCATION/.goduignore" ~/.goduignore
ln -s "$LOCATION/.yamllint.yaml" ~/.yamllint.yaml
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/espanso/base.yml" "$HOME/Library/Application Support/espanso/match/base.yml"
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/espanso/default.yml" "$HOME/Library/Application Support/espanso/config/default.yml"
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
[ "$(uname 2>/dev/null)" == "Darwin" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/Library/Application Support/Code - Insiders/User/settings.json"
[ "$(uname 2>/dev/null)" == "Linux" ] && ln -s "$LOCATION/vscode/settings.json" "$HOME/.config/Code - OSS/User/settings.json"
cd ~/.dotfiles || exit 100
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
mkdir -p ~/.local/share/nvim/swap ~/.local/share/nvim/backup ~/.local/share/nvim/undo
chmod 700 ~/.local/share/nvim/swap ~/.local/share/nvim/backup ~/.local/share/nvim/undo # sensitive information might be in vim tmp files

touch ~/.hushlogin # make sure I don't get any login message from the `login` program

[ "$(uname 2>/dev/null)" == "Darwin" ] && stow karabiner
[ "$(uname 2>/dev/null)" == "Darwin" ] && defaults write -g ApplePressAndHoldEnabled -bool false # disable the press and hold input method https://apple.stackexchange.com/questions/332769/macos-disable-popup-showing-accented-characters-when-holding-down-a-key

[[ $SHELL != *"fish" ]] && chsh -s "$(which fish)"

