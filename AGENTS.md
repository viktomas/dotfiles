`git wta -n <name>` creates a worktree with branch `tv/YYYY-MM/<name>` off `origin/main`.

## Neovim plugins

Plugin management uses `vim.pack` (Neovim 0.12 built-in). When installing, updating, configuring, or removing Neovim plugins, read [nvim/docs/vim-pack.md](nvim/docs/vim-pack.md) first.

## Stow structure

This repo uses [GNU Stow](https://www.gnu.org/software/stow/) to symlink dotfiles into `~`. Each top-level directory is a stow package that mirrors the home directory structure. Running `stow <package>` from the repo root creates symlinks in `~` pointing back here.

Examples:
- `fish/.config/fish/config.fish` → `~/.config/fish/config.fish`
- `kitty/.config/kitty/kitty.conf` → `~/.config/kitty/kitty.conf`
- `pi/.pi/agent/settings.json` → `~/.pi/agent/settings.json`
- `claude/.claude/settings.json` → `~/.claude/settings.json`

To add a new package: create a directory named after the tool, place files inside it mirroring their path relative to `~`, then add `stow <name>` to `install.sh`.
