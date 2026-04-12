# Karabiner — Post-Migration Notes

Karabiner-Elements was replaced by [Kanata](https://github.com/jtroo/kanata) for HRM and symbol layer (2026-04-09). See `kanata.md` for the current setup.

## Installation State

The DriverKit VirtualHIDDevice driver was **kept** — Kanata depends on it.

### Kept (Kanata needs these)

- `/Applications/.Karabiner-VirtualHIDDevice-Manager.app` (hidden app, note the dot)
- `/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/`
- System extension `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` [activated enabled]

### Removed

Apps, launchd services, app support dirs, Homebrew cask record — everything except the driver.

**Do NOT `brew uninstall --cask karabiner-elements`** — it runs `remove_files.sh` which deletes the driver.

### Config source

Preserved at `~/.dotfiles/karabiner/.config/karabiner/` (unstowed). Re-stow: `cd ~/.dotfiles && stow karabiner`.

## Why Karabiner Didn't Work for HRM

Karabiner resolves hold via a timer (`to_if_held_down` after N ms). There's no way to express "resolve as modifier only when an opposite-hand key completes a press-release cycle" — the behavior that makes HRM feel natural (as implemented by the [HRM app](https://github.com/wontaeyang/hrm) and Kanata's `tap-hold-opposite-hand-release`).

Additionally, simultaneous pair rules (needed for same-hand modifier combos like `a+s` → option+command) blocked event propagation between manipulators, causing a **double-option bug**: typing `as` quickly would fire ghost `option DOWN, option UP, option DOWN` events, triggering macOS "double option" shortcuts. The root cause was that pair rules held `s` in a simultaneous wait window, preventing it from canceling `a`'s held-down timer. The only workaround was raising `to_if_held_down_threshold` to ~300ms, making intentional modifier use sluggish.
