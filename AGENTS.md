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

## Global npm tools (pi, qmd)

`pi` and `qmd` are npm packages managed by mise's `npm:` backend in `~/.config/mise/config.toml`. Fish wrapper functions in `fish/.config/fish/functions/{pi,qmd}.fish` pin `node@24` at runtime so the tools work regardless of which node version a project uses locally.

- **Update:** `mise upgrade` (updates all tools including pi and qmd)
- **Config:** `npm:` entries in `~/.config/mise/config.toml` set to `latest`
- **Runtime node pinning:** fish functions call `mise exec node@24 -- command {pi,qmd}`
- **Pi npm setting:** `npmCommand` in `pi/.pi/agent/settings.json` also uses `node@24`

If the global node major version changes (e.g. 24 → 26), update the `node@24` references in the two fish functions and `pi/.pi/agent/settings.json`.

Do **not** install these tools with `npm i -g` — that bypasses mise and installs a duplicate under whatever node happens to be active.

### qmd: better-sqlite3 native binding

`qmd` depends on `better-sqlite3`, which needs a native binding matching the Node ABI. The mise-installed package sometimes ships without a binding for the active Node major (error: `Could not locate the bindings file ... node-vXXX-darwin-arm64`). Rebuild it against the pinned Node:

```sh
cd /Users/tomas/.local/share/mise/installs/npm-tobilu-qmd/*/lib/node_modules/@tobilu/qmd
mise exec node@24 -- npm rebuild better-sqlite3
```

Re-run after each `mise upgrade` that bumps qmd, if the error returns.

## Karabiner-Elements

Home row mods (HRM) and symbol layer are configured via `karabiner/.config/karabiner/generate-hrm.js`. This script generates Karabiner complex modification rules based on [gregorias's approach](https://gregorias.github.io/posts/home-row-mods-karabiner-elements/) and writes them into `karabiner.json`.

Run `node ~/.config/karabiner/generate-hrm.js --apply` to regenerate and apply. Running without `--apply` prints the rules to stdout.

HRM: `a`=alt, `s`=cmd, `d`=shift, `f`=ctrl | `j`=ctrl, `k`=shift, `l`=cmd, `;`=alt
Symbol layer: hold `g` or `h` to activate (symbols left, numpad right). See `karabiner.md` for full layout.

**Do not edit HRM rules in `karabiner.json` directly** — they are overwritten by the script. Edit `generate-hrm.js` instead.
