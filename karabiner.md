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

## DriverKit VirtualHIDDevice — How It Works

Kanata (and formerly Karabiner-Elements) depends on the Karabiner DriverKit VirtualHIDDevice system to output remapped keys. There are three components:

### 1. System Extension (DriverKit dext)

The kernel-level driver that provides the virtual HID keyboard device.

- Installed at `/Library/SystemExtensions/.../org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.dext`
- Managed by `/Applications/.Karabiner-VirtualHIDDevice-Manager.app`
- Verify: `systemextensionsctl list | grep pqrs` → should show `[activated enabled]`
- Survives app uninstalls — managed by macOS system extension framework

### 2. VirtualHIDDevice Daemon (userspace bridge)

A userspace daemon that bridges applications (like kanata) to the DriverKit extension via a Unix socket. **Without this daemon running, kanata cannot output any keys** — it will log `connect_failed asio.system:2` endlessly.

- Binary: `/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon`
- Must run as root
- Source: `Karabiner-DriverKit-VirtualHIDDevice` repo (submodule of Karabiner-Elements at `vendor/Karabiner-DriverKit-VirtualHIDDevice`)
- Canonical plist: `vendor/Karabiner-DriverKit-VirtualHIDDevice/files/LaunchDaemons/org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon.plist`

**Registration:** Karabiner-Elements registers this daemon via `SMAppService.daemon()` in its `ServiceManager-Privileged-Daemons` app. The plist lives inside the KE app bundle. When KE is uninstalled, `SMAppService` can no longer locate the plist — the service shows as "enabled" in `launchctl print system/` but never starts.

**Manual LaunchDaemon install** (required when running without Karabiner-Elements):

```bash
# Install the plist (from the checked-out source)
sudo cp /Users/tomas/workspace/third-party/karabiner/Karabiner-Elements/vendor/Karabiner-DriverKit-VirtualHIDDevice/files/LaunchDaemons/org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon.plist /Library/LaunchDaemons/

sudo launchctl load /Library/LaunchDaemons/org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon.plist
```

Verify it's running:
```bash
ps aux | grep '[K]arabiner-VirtualHIDDevice-Daemon'
```

### 3. Application (kanata)

Connects to the daemon's socket to send virtual key events. See `kanata.md` for setup.

## Why Karabiner Didn't Work for HRM

Karabiner resolves hold via a timer (`to_if_held_down` after N ms). There's no way to express "resolve as modifier only when an opposite-hand key completes a press-release cycle" — the behavior that makes HRM feel natural (as implemented by the [HRM app](https://github.com/wontaeyang/hrm) and Kanata's `tap-hold-opposite-hand-release`).

Additionally, simultaneous pair rules (needed for same-hand modifier combos like `a+s` → option+command) blocked event propagation between manipulators, causing a **double-option bug**: typing `as` quickly would fire ghost `option DOWN, option UP, option DOWN` events, triggering macOS "double option" shortcuts. The root cause was that pair rules held `s` in a simultaneous wait window, preventing it from canceling `a`'s held-down timer. The only workaround was raising `to_if_held_down_threshold` to ~300ms, making intentional modifier use sluggish.
