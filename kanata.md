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

### 1. Build from source (required for Cmd key support)

The Homebrew build disables the `cmd` feature (`kanata was compiled to never allow cmd`). Build from source with `cmd` enabled:

```bash
cd /Users/tomas/workspace/tmp/kanata
cargo build --release --features cmd
```

Install the binary:
```bash
sudo cp /Users/tomas/workspace/tmp/kanata/target/release/kanata /usr/local/bin/kanata
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

## Full config — HRM + symbol layer + extra rules

The full config translates everything from the Karabiner setup (`generate-hrm.js` + manual rules).

### What to translate

**Home row mods** (8 keys):
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

**Symbol layer triggers** (2 keys, same tap-hold pattern):
| Key | Tap | Hold |
|-----|-----|------|
| `g` | g | activate symbol layer |
| `h` | h | activate symbol layer |

**Symbol layer mappings** (when g or h held):
```
LEFT HAND                          RIGHT HAND
  q=!    w=@    e=[    r=]    t=|    y=_    u=7    i=8    o=9    p=*
  a=#    s=$    d=(    f=)    g=`    h=-    j=4    k=5    l=6    ;=+
  z=%    x=^    c={    v=}    b=~    n=&    m=1    ,=2    .=3    /=/
```

**Extra rules** (from Karabiner manual rules):
| Rule | Karabiner | Kanata |
|------|-----------|--------|
| Caps Lock → Escape | Simple modification (enabled) | Direct key in `deflayer` |
| Caps Lock → Ctrl (tap=Escape) | Complex rule (disabled) | Skip (disabled) |
| Right Shift: tap → Ctrl+Y, hold → Shift | `to` + `to_if_alone` | `tap-hold` with `multi` tap |
| Space+j in Ghostty → Ctrl+Shift+j | `simultaneous` + `frontmost_application_if` | **Cannot translate** — Kanata has no per-app conditions. Use Ghostty keybind config instead. |
| Space+k in Ghostty → Ctrl+Shift+k | Same | Same |
| Space+j global → Cmd+Shift+[ | `simultaneous` | `defchords` |
| Space+k global → Cmd+Shift+] | `simultaneous` | `defchords` |

### Kanata config structure

```lisp
(defcfg
  process-unmapped-keys yes
  concurrent-tap-hold yes
)

(defsrc
  esc  f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12
  grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
  tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
  caps a    s    d    f    g    h    j    k    l    ;    '    ret
  lsft z    x    c    v    b    n    m    ,    .    /    rsft      up
  fn   lctl lalt lmet           spc            rmet ralt     left down rght
)

(defvar
  tap-time  200   ;; tune to typing speed
  hold-time 150

  left-hand-keys (
    q w e r t
    a s d f g
    z x c v b
  )
  right-hand-keys (
    y u i o p
    h j k l ;
    n m , . /
  )
)

;; ── Typing streak suppression ──────────────────────────────────

(deflayer base
  esc  f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12
  grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
  tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
  esc  @a   @s   @d   @f   @g   @h   @j   @k   @l   @;   '    ret
  lsft z    x    c    v    b    n    m    ,    .    /    @rs       up
  fn   lctl lalt lmet           @sj            rmet ralt     left down rght
)

(deflayer nomods
  esc  f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12
  grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
  tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
  esc  a    s    d    f    g    h    j    k    l    ;    '    ret
  lsft z    x    c    v    b    n    m    ,    .    /    rsft      up
  fn   lctl lalt lmet           spc            rmet ralt     left down rght
)

;; ── Symbol layer ───────────────────────────────────────────────

(deflayer sym
  _    _    _    _    _    _    _    _    _    _    _    _    _
  _    _    _    _    _    _    _    _    _    _    _    _    _    _
  _    S-1  S-2  [    ]    S-\  S--  7    8    9    S-8  _    _    _
  _    S-3  S-4  S-9  S-0  grv  -    4    5    6    S-=  _    _
  _    S-5  S-6  S-[  S-]  S-grv S-7 1    2    3    /    _         _
  _    _    _    _              _              _    _         _  _  _
)

;; ── Aliases ────────────────────────────────────────────────────

(deffakekeys
  to-base (layer-switch base)
)

(defalias
  tap (multi
    (layer-switch nomods)
    (on-idle-fakekey to-base tap 20)
  )

  ;; Home row mods — left hand
  a (tap-hold-release-keys $tap-time $hold-time (multi a @tap) lalt $left-hand-keys)
  s (tap-hold-release-keys $tap-time $hold-time (multi s @tap) lmet $left-hand-keys)
  d (tap-hold-release-keys $tap-time $hold-time (multi d @tap) lsft $left-hand-keys)
  f (tap-hold-release-keys $tap-time $hold-time (multi f @tap) lctl $left-hand-keys)

  ;; Home row mods — right hand
  j (tap-hold-release-keys $tap-time $hold-time (multi j @tap) rctl $right-hand-keys)
  k (tap-hold-release-keys $tap-time $hold-time (multi k @tap) rsft $right-hand-keys)
  l (tap-hold-release-keys $tap-time $hold-time (multi l @tap) rmet $right-hand-keys)
  ; (tap-hold-release-keys $tap-time $hold-time (multi ; @tap) ralt $right-hand-keys)

  ;; Symbol layer triggers — same bilateral tap-hold, hold activates layer
  g (tap-hold-release-keys $tap-time $hold-time (multi g @tap) (layer-while-held sym) $left-hand-keys)
  h (tap-hold-release-keys $tap-time $hold-time (multi h @tap) (layer-while-held sym) $right-hand-keys)

  ;; Right Shift: tap → Ctrl+Y (zellij pane mode), hold → Shift
  rs (tap-hold 200 200 C-y rsft)

  ;; Space+j/k chords → Cmd+Shift+[/] (tab switching)
  sj (chord spacechords spc)
)

;; ── Chords ─────────────────────────────────────────────────────

;; Space+j → Cmd+Shift+[   Space+k → Cmd+Shift+]
;; Space alone → space
(defchords spacechords 50
  (spc) spc
  (j)   j
  (k)   k
  (spc j) S-M-[
  (spc k) S-M-]
)
```

### What can't be translated

**Per-app rules** — Kanata has no `frontmost_application_if` equivalent. The Ghostty-specific Space+j/k → Ctrl+Shift+j/k rules must move to Ghostty's own keybind config:

```
# In Ghostty config (~/.config/ghostty/config):
keybind = ctrl+shift+j=...
keybind = ctrl+shift+k=...
```

Or use the global Space+j/k chord (Cmd+Shift+brackets) for tab switching everywhere, and configure Ghostty/zellij to respond to that.

**right_command → 0 in symbol layer** — The Karabiner config mapped `right_command` to `0` when the symbol layer was active. Modifier keys don't generate keyDown/keyUp in macOS (they generate flagsChanged), so this is tricky. Kanata may handle `rmet` in `defsrc`/`deflayer` differently. Test whether placing `0` at the `rmet` position in the `sym` layer works. If not, skip it (was already noted as edge case in the Karabiner config).

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
