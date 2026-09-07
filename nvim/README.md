# Neovim

Config is stow-managed: `nvim/.config/nvim/` → `~/.config/nvim/`. The entry point
is `init.lua`, with per-plugin setup in `lua/plugins/*.lua`.

## Docs

| Topic | Doc |
|---|---|
| Plugin management (`vim.pack`: add, update, pin, delete, hooks) | `docs/vim-pack.md` |
| Fennel + love2d LSP (hover docs, completions in `.fnl`) | `docs/fennel-love2d.md` |
| The theme: attention-based grayscale highlighting for Go/TypeScript | `THEME.md` |

## Theme

Go and TypeScript are painted by a hand-rolled attention-based theme
(`lua/user/theme.lua`) layered on tokyonight: grayscale tiers, no hue outside
diagnostics, surfaces matched to the terminal background. It ships in two
variants — `dark` (default) and `light` — switched with `:ThemeVariant`; any
change must be made and measured in **both**. Read `THEME.md` before touching
highlight groups, tier rules or `after/queries/`, and verify changes by measuring
the screen with the `nvim-theme` skill (`pi/.pi/agent/skills/nvim-theme/`) rather
than by eye.

## Plugins — vim.pack

Plugin management uses `vim.pack`, the built-in manager added in Neovim 0.12.
When installing, updating, configuring, or removing plugins, read
`docs/vim-pack.md` first. Plugins are declared in a single `vim.pack.add({...})`
call in `init.lua` and must always be pinned to a commit hash or version tag.
The lockfile `nvim-pack-lock.json` is tracked in git — never edit it by hand.

## Known issues

- Replacing visually selected text by pressing `p` removes leading spaces. Fix it.
