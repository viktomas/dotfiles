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

## Karabiner-Elements

Home row mods (HRM) and symbol layer are configured via `karabiner/.config/karabiner/generate-hrm.js`. This script generates Karabiner complex modification rules based on [gregorias's approach](https://gregorias.github.io/posts/home-row-mods-karabiner-elements/) and writes them into `karabiner.json`.

Run `node ~/.config/karabiner/generate-hrm.js --apply` to regenerate and apply. Running without `--apply` prints the rules to stdout.

HRM: `a`=alt, `s`=cmd, `d`=shift, `f`=ctrl | `j`=ctrl, `k`=shift, `l`=cmd, `;`=alt
Symbol layer: hold `g` or `h` to activate (symbols left, numpad right). See `karabiner.md` for full layout.

**Do not edit HRM rules in `karabiner.json` directly** — they are overwritten by the script. Edit `generate-hrm.js` instead.
