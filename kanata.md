# Kanata — Installation & Migration from Karabiner

> **⚠️ Experimental (2026-04-13):** No neutral keys remain. `tab` is left-hand, `spc` and `ret` are right-hand. This enables combos like Cmd+Space, Cmd+Return, and Cmd+Tab with the appropriate opposite-hand HRM keys, but may cause misfires on fast rolls (e.g. `s→space` after a 150ms+ pause = Cmd+Space). Monitoring — may need to re-introduce neutral keys if misfires are problematic.

- kanata live in /Users/tomas/workspace/tmp/kanata, if not, clone it there from git@github.com:jtroo/kanata.git
- hrm app lives in  /Users/tomas/workspace/tmp/hrm, if not, clone it there from git@github.com:wontaeyang/hrm.git

## Why Kanata

Karabiner-Elements can't implement timeless home row mods (see `karabiner.md` for the full analysis). Kanata provides `tap-hold-opposite-hand-release` — bilateral filtering via `defhands` with release-based resolution, the closest match to the HRM app's timeless behavior. It uses the same Karabiner DriverKit virtual keyboard driver under the hood.

## Prerequisites

The Karabiner DriverKit VirtualHIDDevice system must be installed and running. This includes the system extension (dext) and the userspace daemon. See `karabiner.md` "DriverKit VirtualHIDDevice" section for full details and install instructions.

Verify:
```bash
# System extension is active
systemextensionsctl list | grep pqrs
# Should show: org.pqrs.Karabiner-DriverKit-VirtualHIDDevice [activated enabled]

# Userspace daemon is running (required for kanata to output keys)
ps aux | grep '[K]arabiner-VirtualHIDDevice-Daemon'
```

## Installation

### 1. Install via Homebrew

```bash
brew install kanata
```

The current config doesn't need the `cmd` feature (which Homebrew disables). The `cmd` feature allows executing arbitrary shell commands from key bindings (e.g., `(cmd open -a Safari)`). If you ever need it, build from source with `--features cmd`:

```bash
cd /Users/tomas/workspace/tmp/kanata
cargo build --release --features cmd
sudo cp target/release/kanata /usr/local/bin/kanata
```

### 2. Config file

Config lives in the dotfiles stow structure:

```
~/.dotfiles/kanata/.config/kanata/kanata.kbd  →  ~/.config/kanata/kanata.kbd
```

Stow it:
```bash
cd ~/.dotfiles && stow kanata
```

### 3. Grant Input Monitoring permission

Even running as root via LaunchDaemon, macOS TCC requires Input Monitoring access for the binary:

**System Settings → Privacy & Security → Input Monitoring** → `+` → `Cmd+Shift+G` → `/usr/local/bin/kanata` → Add

Without this, kanata logs `IOHIDDeviceOpen error: (iokit/common) not permitted` and can't grab keyboards.

### 4. LaunchDaemon (auto-start at boot)

The VHIDDevice daemon must already be running (see Prerequisites). Kanata runs as a system LaunchDaemon:

```bash
sudo tee /Library/LaunchDaemons/com.kanata.daemon.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.kanata.daemon</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/kanata</string>
    <string>--cfg</string>
    <string>/Users/tomas/.config/kanata/kanata.kbd</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/var/log/kanata.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/kanata.err</string>
</dict>
</plist>
EOF

sudo launchctl load /Library/LaunchDaemons/com.kanata.daemon.plist
```

### Operations

Reload after config changes:
```bash
sudo launchctl kickstart -k system/com.kanata.daemon
```

Check status:
```bash
ps aux | grep kanata
tail -f /var/log/kanata.log
tail -f /var/log/kanata.err
```

Force-quit kanata (physical keys, before remapping): `lctl+spc+esc`

## Config — HRM + symbol layer + extra rules

Config file: `kanata/.config/kanata/kanata.kbd` (stowed to `~/.config/kanata/kanata.kbd`).

### How it works

All HRM and layer-trigger keys use `tap-hold-opposite-hand-release` with `defhands` bilateral filtering. This is the closest Kanata gets to the HRM Swift app's timeless tap-hold behavior.

**Decision flow for an HRM key (e.g., `f` → Ctrl):**

1. You press `f`. Kanata checks `require-prior-idle` (150ms global): if another key was pressed within 150ms, immediately output `f` as tap — no waiting state. This handles fast typing streaks.
2. Otherwise, `f` enters the waiting state. All subsequent keys are buffered.
3. Another key is pressed:
   - **Same hand** (e.g., `d`, `g`) → `(same-hand tap)` → immediately resolve `f` as tap. No misfire possible.
   - **Opposite hand** (e.g., `j`) → wait for `j` to be **released** (press+release). Once `j↑` arrives, resolve `f` as hold (Ctrl). Buffered `j` is output as `Ctrl+j`.
   - **No neutral keys** — all keys are assigned to a hand. Tab is left-hand, Space and Return are right-hand. This means every key participates in bilateral filtering. Trade-off: fast cross-hand rolls involving these keys could misfire (mitigated by `require-prior-idle 150`).
4. If 500ms pass with no qualifying key → `(timeout tap)` → output `f` as tap. This is a safety net, not the normal path.

**Important:** Every key that should trigger hold resolution must be in `defhands`. The number row (`1-0`), symbols (`- = [ ] \ '`), grave, `tab`, and arrow keys are all assigned — left hand gets `grv 1 2 3 4 5 tab left rght`, right hand gets `6 7 8 9 0 - = [ ] \ ' spc ret up down`. Without this, combos like `cmd+1` (hold `l`, tap `1`) or `cmd+tab` (hold `l`, tap `tab`) wouldn't work because unassigned keys can't resolve the tap-hold.

**Arrow key hand assignment** follows the Kinesis layout: `left`/`rght` are left-hand, `up`/`down` are right-hand. On a normal keyboard (all arrows right-hand), this means right-hand HRM + `left`/`rght` won't resolve as hold — use left-hand HRM instead (e.g., `s`=Cmd + `left`).

**Why `-release` matters:** Without it (`tap-hold-opposite-hand`), hold triggers the moment an opposite-hand key is *pressed*. With `-release`, it waits for press+release. This prevents misfires on fast cross-hand overlaps like `f↓ j↓ f↑ j↑` where you release `f` before `j` — should be `fj`, not `Ctrl+j`.

**Bug fix (PR [#2017](https://github.com/jtroo/kanata/pull/2017)):** The `-release` variant had a bug where same-hand keys that were still held (no release in the queue) were skipped entirely. A subsequent opposite-hand key with its release in the queue would then incorrectly trigger Hold. Example: `f↓ d↓ j↓ j↑` — `d` had no release yet so it was skipped, then `j`'s release triggered `f` as Hold(ctrl). The fix applies the release requirement only to opposite-hand/neutral/unknown keys; same-hand keys resolve immediately on press. This fix is in kanata `main` (commit `5e894a0`), not yet in a release — the `/usr/local/bin/kanata` binary is built from this branch.

### What's implemented

**Home row mods** (8 keys, `tap-hold-opposite-hand-release` with `defhands`):
| Key | Tap | Hold |
|-----|-----|------|
| `a` | a | left_option |
| `s` | s | left_command |
| `d` | d | left_shift |
| `f` | f | left_control |
| `j` | j | right_control |
| `k` | k | right_shift |
| `l` | l | right_command |
| `;` | ; | right_option |

**Symbol layer triggers** (2 keys, same `tap-hold-opposite-hand-release`):
| Key | Tap | Hold |
|-----|-----|------|
| `g` | g | activate sym layer |
| `h` | h | activate sym layer |

**Symbol layer mappings** (when g or h held): see `kanata/.config/kanata/symbol-layer.txt` for the full layout. This file doubles as a cheat sheet — accessible in zellij via `Ctrl+y g` (opens a floating overlay).

**Media key row** (F1–F12 mapped to macOS media actions):

Kanata intercepts the keyboard HID device, so macOS's default media key behavior (brightness, volume, etc.) is lost. The config explicitly maps F1–F12 to their media equivalents:

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| F1 | `brdn` (Brightness Down) | F7 | `prev` (Previous Track) |
| F2 | `brup` (Brightness Up) | F8 | `pp` (Play/Pause) |
| F3 | `_` (passthrough) | F9 | `next` (Next Track) |
| F4 | `_` (passthrough) | F10 | `mute` |
| F5 | `bldn` (Kbd Backlight Down) | F11 | `vold` (Volume Down) |
| F6 | `blup` (Kbd Backlight Up) | F12 | `volu` (Volume Up) |

F3 and F4 are passthrough (`_`) — Mission Control and Spotlight are macOS system shortcuts that fire on the F3/F4 keycodes directly.

**Extra rules**:
| Rule | Implementation |
|------|---------------|
| Caps Lock → Escape | `esc` at caps position in `deflayer base` |
| Right Shift: tap → Ctrl+Y, hold → Shift | `(tap-hold 200 200 C-y rsft)` |

**Typing streak suppression**: `tap-hold-require-prior-idle 150` in `defcfg`. If any key was pressed within 150ms before an HRM key, it immediately outputs the letter — no waiting state, zero latency. This replaces the previous `nomods` layer + `on-idle-fakekey` workaround.

**Space+j/k chords** (tab switching via `defchordsv2`):
| Chord | Action | Output |
|-------|--------|--------|
| Space+j | Previous tab | `Cmd+Shift+[` |
| Space+k | Next tab | `Cmd+Shift+]` |

`defchordsv2` processes keys **before** layer/tap-hold actions, so when `spc+j` are pressed within 50ms, the chord fires directly — the HRM tap-hold on `j`/`k` is never entered. `chords-v2-min-idle 150` in `defcfg` disables chord detection for 150ms after any non-chord keypress, preventing misfires when rolling `spc→j` during normal typing (e.g., " just").

The Karabiner config had Ghostty-specific rules that sent `Ctrl+Shift+j/k` (zellij tab switch) instead of `Cmd+Shift+[/]`. Kanata has no per-app rules (`frontmost_application_if`), so Ghostty-specific behavior must be configured in Ghostty's keybinds.

### What's not implemented

**right_command → 0 in symbol layer** — Modifier keys behave differently in macOS (flagsChanged vs keyDown). Test whether placing `0` at the `rmet` position in the `sym` layer works.

## Tuning timings

| Parameter | Value | What it does |
|-----------|-------|--------------|
| `hold-time` | 500 | Safety-net timeout. With `(timeout tap)`, expiry outputs the letter — no accidental mods. Set high so it never interferes with real modifier use. |
| `require-prior-idle` | 150 | If another key was pressed within 150ms before the HRM key, skip waiting entirely → instant tap. Handles fast typing streaks. |
| `chords-v2-min-idle` | 150 | After any non-chord keypress, chord detection is disabled for this duration. Prevents misfires during fast typing rolls. |
| chord timeout | 50 | Time window (per chord) within which both keys must be pressed for the chord to fire. |

The primary decision mechanism is structural (bilateral filtering + release-order), not timer-based. Adjust `require-prior-idle` down (e.g., 100ms) if mods feel sluggish during intentional use, or up (e.g., 200ms) if typing still triggers accidental mods.

Use `sudo kanata --cfg ... --debug` to see event timings and tune. The Kanata simulator at https://jtroo.github.io/kanata-sim/ is also useful.

## Multi-modifier combos

Same-hand multi-mod combos (e.g. `f`+`d` for ctrl+shift) are **not supported** — same-hand keys resolve immediately as tap via `(same-hand tap)`. This matches the HRM app's default behavior (`holdTriggerOnRelease: false`).

The HRM app has a `holdTriggerOnRelease` option (default: off) that when enabled makes same-hand keys stay undecided instead of resolving as tap. Both undecided keys then resolve as hold when an opposite-hand key completes a press+release cycle. Kanata's `tap-hold-opposite-hand-release` has no equivalent — `(same-hand tap)` is the only same-hand option.

Cross-hand multi-mod combos (e.g. `s`+`j` for cmd+ctrl) work in the HRM app: pressing `s↓ j↓` then a non-mod-tap key that gets released resolves whichever mod-tap key is on the opposite hand. In practice this requires two separate trigger keys (one per hand) to resolve both mods. In kanata, cross-hand mod-tap keys pressed together would deadlock — each waits for the other's release, and self-release resolves as tap.

## Compared to the HRM Swift app

`tap-hold-opposite-hand-release` is ~95% of the HRM app's default behavior:

| Feature | HRM app (default) | Kanata config |
|---------|---------|---------------|
| Bilateral filtering | ✅ per-hand key sets | ✅ `defhands` |
| Hold on opposite-hand key release | ✅ key completes press+release cycle | ✅ `-release` variant waits for press+release |
| Same-hand → always tap | ✅ structural (`holdTriggerOnRelease: false`) | ✅ `(same-hand tap)` structural |
| Same-hand multi-mod combos | ⚠️ opt-in via `holdTriggerOnRelease: true` | ❌ not supported |
| No timeout (truly timeless) | ✅ no timer, waits forever | ⚠️ 500ms timeout exists, but `(timeout tap)` makes it harmless |
| Typing streak detection | ✅ prior-idle check | ✅ `require-prior-idle 150` |
| Solo hold (hold key alone, no other key) | Stays undecided forever | Resolves as tap after 500ms |

The only behavioral gap: holding an HRM key alone for 500ms then pressing another key. HRM app would still resolve as modifier; Kanata already resolved as tap. In practice this doesn't happen — you don't hold `f` for half a second thinking, then decide to use it as Ctrl.

## Open questions

- **Symbol layer + HRM interaction** — when symbol layer is active via `g`/`h` hold, pressing an HRM key (e.g., `a`) should output the symbol (`#`), not enter tap-hold. The `sym` deflayer maps `a` directly to `S-3`, bypassing the alias. Verify this works as expected.

## Reference

- Kanata source: `/Users/tomas/workspace/tmp/kanata`
- Kanata docs: https://github.com/jtroo/kanata/blob/main/docs/config.adoc
- Kanata simulator: https://jtroo.github.io/kanata-sim/
- Karabiner analysis: `~/.dotfiles/karabiner.md`
- Original Karabiner config generator: `~/.dotfiles/karabiner/.config/karabiner/generate-hrm.js`
