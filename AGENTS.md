`git wta -n <name>` creates a worktree with branch `tv/YYYY-MM/<name>` off `origin/main`.

## Local dev environment & config

Stow structure, fish shell, neovim (`vim.pack`), and the global npm tools (pi, qmd)
are documented in the `dotfiles` skill (`pi/.pi/agent/skills/dotfiles/SKILL.md`).

## Keyboard mapping

Home row mods (HRM) and the symbol layer are implemented in **kanata**. Karabiner's
DriverKit driver is kept only as kanata's virtual-HID dependency. Full setup,
layout, and timings are in `kanata/README.md`; the Karabiner driver and migration
notes are in `karabiner/README.md`.

HRM: `a`=alt, `s`=cmd, `d`=shift, `f`=ctrl | `j`=ctrl, `k`=shift, `l`=cmd, `;`=alt
Symbol layer: hold `g` or `h` to activate (symbols left, numpad right).
