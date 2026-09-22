# Neovim

Config is stow-managed: `nvim/.config/nvim/` → `~/.config/nvim/`. The entry point
is `init.lua`, with per-plugin setup in `lua/plugins/*.lua`.

## Docs

| Topic | Doc |
|---|---|
| Plugin management (`vim.pack`: add, update, pin, delete, hooks) | `docs/vim-pack.md` |
| Fennel + love2d LSP (hover docs, completions in `.fnl`) | `docs/fennel-love2d.md` |
| `gt` on a `$task-id` in markdown switches to that task's zellij session | `lua/plugins/task.lua` |
| The theme: attention-based grayscale highlighting for Go/TypeScript | `THEME.md` |

## Markdown: `gt` jumps to a task session

`lua/plugins/task.lua` adds a markdown-only `gt` mapping: with the cursor on a
`$task-id` token it runs `task switch <id>`, switching the zellij client to that
task's session. Task ids are the ones from the [`task`](https://gitlab.com/viktomas/task)
CLI, and generated documents (e.g. `~/workspace/gl/work/dashboard.md`) reference
tasks with the `$` prefix so a brief can be navigated straight into the work.

Why a plain keymap and not the markdown LSP (`gowl`): switching sessions is a
side effect on the multiplexer, not navigation to a location, so there is no
`Location` for `textDocument/definition` to return. This stays fully decoupled
from `gowl`: no server changes, no shared link detection, nothing to keep in
sync.

The token pattern is `%$([%l%d][%l%d-]*)`, i.e. lowercase letters, digits and
dashes only, because task ids are slugified. That deliberately ignores `$HOME`,
`$TASK_ID`, `$(date +%F)` and similar shell/env syntax. Failures are reported
via `vim.notify`: no token under the cursor (warn), `task` missing from `$PATH`,
nvim not running inside zellij, or the CLI's own stderr (e.g.
`error: task not found: <id>`) with its exit code as a fallback.

Not implemented on purpose: no live indicator for tasks with a running pi
agent. That state changes without any buffer edit (a pid can die at any time),
so it would need a polling server or a client-side timer. Deferred until it
turns out to be missed.

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
