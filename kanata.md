# Kanata — Installation & Migration from Karabiner

## Why Kanata

Karabiner-Elements can't implement timeless home row mods (see `karabiner.md` for the full analysis). Kanata provides `tap-hold-release-keys` which resolves hold on opposite-hand key release — the missing primitive. It uses the same Karabiner DriverKit virtual keyboard driver under the hood.

## Prerequisites

The Karabiner DriverKit VirtualHIDDevice driver must be installed and active (kept during Karabiner-Elements uninstall — see `karabiner.md` Installation State section).

Verify:
```bash
systemextensionsctl list | grep pqrs
# Should show: org.pqrs.Karabiner-DriverKit-VirtualHIDDevice [activated enabled]
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

The VHIDDevice daemon is already running from the Karabiner DriverKit install (persists across reboots via its own LaunchDaemon at `/Library/LaunchDaemons/org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon.plist`).

Kanata runs as a system LaunchDaemon:

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

### What's implemented

**Home row mods** (8 keys, bilateral `tap-hold-release-keys`):
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

**Symbol layer triggers** (2 keys, same bilateral tap-hold):
| Key | Tap | Hold |
|-----|-----|------|
| `g` | g | activate sym layer |
| `h` | h | activate sym layer |

**Symbol layer mappings** (when g or h held):
```
LEFT HAND                          RIGHT HAND
  q=!    w=@    e=[    r=]    t=|    y=_    u=7    i=8    o=9    p=*
  a=#    s=$    d=(    f=)    g=`    h=-    j=4    k=5    l=6    ;=+
  z=%    x=^    c={    v=}    b=~    n=&    m=1    ,=2    .=3    /=/
```

**Extra rules**:
| Rule | Implementation |
|------|---------------|
| Caps Lock → Escape | `esc` at caps position in `deflayer base` |
| Right Shift: tap → Ctrl+Y, hold → Shift | `(tap-hold 200 200 C-y rsft)` |

**Typing streak suppression**: After a tap, switches to `nomods` layer (no HRM aliases) then returns to `base` after 20ms idle via `on-idle-fakekey`.

### What's not implemented

**Space+j/k chords** — `defchords` requires all participating keys to be bound to the chord, but `j` and `k` are already HRM aliases. These two mechanisms conflict. Options:
1. Move tab switching to a dedicated key combo (e.g., use symbol layer: hold `g` + press a key)
2. Use `fork` or `switch` to route `j`/`k` differently when space is held
3. Accept the limitation and use Cmd+Shift+[ / Cmd+Shift+] directly

**Per-app rules** — Kanata has no `frontmost_application_if`. Ghostty-specific Space+j/k rules must move to Ghostty's keybind config.

**right_command → 0 in symbol layer** — Modifier keys behave differently in macOS (flagsChanged vs keyDown). Test whether placing `0` at the `rmet` position in the `sym` layer works.

## Tuning timings

Start with conservative values and tighten:

| Parameter | Start | Aggressive | What it does |
|-----------|-------|------------|--------------|
| `tap-time` | 200 | 150 | Max ms after press where release still counts as tap |
| `hold-time` | 150 | 120 | Min ms before hold can activate (with `tap-hold-release-keys`, other-key-release is the main trigger, not this timer) |

Use `sudo kanata --cfg ... --debug` to see event timings and tune. The Kanata simulator at https://jtroo.github.io/kanata-sim/ is also useful.

Consider per-finger timings (pinkies are slower):
```lisp
(defvar
  pinky-tap  250
  pinky-hold 180
  finger-tap 200
  finger-hold 150
)
```

## Open questions

- **`tap-hold-release-order`** (urob's timeless mods) — pure release-order resolution with no timeout. Available in Kanata 1.10+. May be better than `tap-hold-release-keys` for HRM. Try both and compare feel.
- **Chord interaction with HRM** — the Space+j/k chords involve `j` which is also an HRM key. Need to test whether `defchords` and `tap-hold-release-keys` interact cleanly, or if `j` needs to be handled differently in the chord context.
- **Symbol layer + HRM interaction** — when symbol layer is active via `g`/`h` hold, pressing an HRM key (e.g., `a`) should output the symbol (`#`), not enter tap-hold. The `sym` deflayer maps `a` directly to `S-3`, bypassing the alias. Verify this works as expected.

## Reference

- Kanata source: `/Users/tomas/workspace/tmp/kanata`
- Kanata docs: https://github.com/jtroo/kanata/blob/main/docs/config.adoc
- Kanata simulator: https://jtroo.github.io/kanata-sim/
- Karabiner analysis: `~/.dotfiles/karabiner.md`
- Original Karabiner config generator: `~/.dotfiles/karabiner/.config/karabiner/generate-hrm.js`
