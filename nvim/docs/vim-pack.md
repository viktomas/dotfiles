# Neovim Plugin Management (vim.pack)

This config uses `vim.pack` — the built-in plugin manager added in Neovim 0.12.

## Config location

All plugins are declared in `nvim/.config/nvim/init.lua` (symlinked to `~/.config/nvim/init.lua`).

Plugins live in a single `vim.pack.add({...})` call. Per-plugin setup is in `lua/plugins/*.lua`.

Lockfile is at `~/.config/nvim/nvim-pack-lock.json` — tracked in git, never edit by hand.

Plugins are stored on disk at `~/.local/share/nvim/site/pack/core/opt/`.

## Adding a plugin

1. Add an entry to the `vim.pack.add({...})` table in `init.lua`:
   ```lua
   { src = 'https://github.com/owner/repo', version = '<commit-or-tag>' },
   ```
2. Always pin to a specific commit hash or version tag — never leave `version` unset.
3. Create `lua/plugins/<name>.lua` for any plugin-specific setup if needed.
4. The next time Neovim starts it will prompt to install new plugins (press `a` to allow all).

## Updating a plugin

From inside Neovim:
```
:lua vim.pack.update()                          -- update all, shows confirmation buffer
:lua vim.pack.update({ 'plugin-name' })         -- update one plugin
:lua vim.pack.update(nil, { force = true })     -- skip confirmation, apply immediately
```

In the confirmation buffer: `:write` to confirm, `:quit` to cancel.

After updating, get the new commit hash and update the `version` field in `init.lua` to keep it pinned.

## Pinning / locking versions

All plugins must have an explicit `version`. Use a commit hash for stability:
```lua
{ src = 'https://github.com/folke/tokyonight.nvim', version = 'v4.11.0' },
{ src = 'https://github.com/stevearc/oil.nvim',     version = '0fcc83805ad11cf714a949c98c605ed717e0b83e' },
```

To find the current commit of an installed plugin:
```bash
git -C ~/.local/share/nvim/site/pack/core/opt/<plugin-name> rev-parse HEAD
```

## Deleting a plugin

1. Remove its entry from `vim.pack.add({...})` in `init.lua`.
2. Remove any `require("plugins.<name>")` call.
3. Delete the plugin files from disk (do NOT delete manually — use vim.pack):
   ```
   :lua vim.pack.del({ 'plugin-name' })
   ```

Do not delete the directory by hand — that leaves the lockfile out of sync and Neovim will reinstall it.

## Hooks (post-install / post-update)

Use an autocommand on `PackChanged` **before** the `vim.pack.add()` call:
```lua
vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
  local name, kind = ev.data.spec.name, ev.data.kind
  if name == 'nvim-treesitter' and (kind == 'install' or kind == 'update') then
    if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
    vim.cmd('TSUpdate')
  end
end })
```

Change kinds: `install`, `update`, `delete`.

## Troubleshooting

```
:checkhealth vim.pack
```

This detects lockfile issues, plugins not aligned with disk, and inactive (orphaned) plugins.

To revert to the last known-good state (lockfile), revert `nvim-pack-lock.json` in git, then:
```
:lua vim.pack.update(nil, { target = 'lockfile' })
```
