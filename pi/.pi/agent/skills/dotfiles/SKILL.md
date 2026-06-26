---
name: dotfiles
description: Knowledge about Tomas's local dev environment and config — keyboard mapping (kanata), fish shell, terminal (ghostty), zellij, neovim, pi/qmd tooling, and the stow-managed dotfiles repo. Use whenever the user talks about their keyboard mapping, shell, terminal, editor, pi, or other local tools. Keywords - dotfiles, kanata, keyboard mapping, home row mods, hrm, fish, ghostty, terminal, zellij, neovim, nvim, vim.pack, qmd, mise, stow, espanso, yabai, skhd.
---

# Dotfiles & Local Dev Environment

The dotfiles repo is at `~/.dotfiles`. It uses [GNU Stow](https://www.gnu.org/software/stow/):
each top-level directory is a package that mirrors the home directory. Running
`stow <package>` from the repo root symlinks its files into `~`.

Examples:
- `fish/.config/fish/config.fish` → `~/.config/fish/config.fish`
- `ghostty/.config/ghostty/config.ghostty` → `~/.config/ghostty/config.ghostty`
- `pi/.pi/agent/settings.json` → `~/.pi/agent/settings.json`

To add a package: create a directory named after the tool, mirror the file's path
relative to `~` inside it, then add `stow <name>` to `install.sh`.

## Where to read more

Each tool documents its own setup in a README inside its stow package. Read the
relevant one before changing that tool's config:

| Topic | Doc |
|---|---|
| Repo overview, install, stow, mac-specific setup | `~/.dotfiles/README.md` |
| Project-wide conventions | `~/.dotfiles/AGENTS.md` |
| Keyboard mapping (kanata: HRM, symbol layer, tab chords) | `~/.dotfiles/kanata/README.md` |
| Karabiner DriverKit driver (kanata's HID dependency) | `~/.dotfiles/karabiner/README.md` |
| Neovim (plugins via `vim.pack`, Fennel LSP) | `~/.dotfiles/nvim/README.md` |
| Ghostty terminal + tab switching | `~/.dotfiles/ghostty/README.md` |
| Fish shell | `~/.dotfiles/fish/README.md` |
| pi & qmd (global npm tools via mise) | `~/.dotfiles/pi/README.md` |

## Quick reference

- **Shell is fish.** Use fish syntax for env/aliases/PATH. Test with
  `fish -c '<command>'`; interactive-only config needs `fish -ic '<command>'`.
  Details: `~/.dotfiles/fish/README.md`.
- **Keyboard mapping is kanata** (HRM + symbol layer; Karabiner's DriverKit
  driver is kept only as kanata's virtual-HID dependency). HRM: `a`=alt,
  `s`=cmd, `d`=shift, `f`=ctrl | `j`=ctrl, `k`=shift, `l`=cmd, `;`=alt.
  Tab switching: Space+j / Space+k. Details: `~/.dotfiles/kanata/README.md`.
- **Neovim plugins use `vim.pack`** (Neovim 0.12 built-in). Read
  `~/.dotfiles/nvim/README.md` before changing plugins.
- **pi & qmd are mise-managed global npm tools** pinned to `node@24`. Update with
  `mise upgrade`; never `npm i -g`. Details: `~/.dotfiles/pi/README.md`.
