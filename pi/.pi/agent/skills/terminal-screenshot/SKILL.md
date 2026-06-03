---
name: terminal-screenshot
description: Capture terminal screenshots and GIF recordings from tmux sessions using freeze and agg. Use when you need to screenshot a TUI app, generate terminal images, or convert asciinema casts to GIFs.
---

# Terminal Screenshots & Recordings

Capture screenshots from live tmux sessions with `freeze`, convert asciinema `.cast` files to GIFs with `agg`.

## Screenshots from tmux (freeze)

Capture a tmux pane and render it as a terminal image:

```bash
freeze --execute "tmux capture-pane -t $SESSION -p -e" \
  --output screenshot.png --window --padding 20 \
  --font.family "JetBrainsMono Nerd Font Mono"
```

### With tui-testing

Drive the app to the desired state with `tui_ctrl`, then snapshot:

```bash
CTRL="path/to/tui_ctrl.ts"
$CTRL launch -s demo --cols 100 --rows 25 --cwd "$PROJECT" node app.js
$CTRL wait -s demo "Ready" --timeout 30
sleep 1

# Navigate to the screen you want to capture
$CTRL writeln -s demo "some input"
$CTRL wait -s demo "Expected output" --timeout 15
sleep 1

# Capture
freeze --execute "tmux capture-pane -t demo -p -e" \
  --output shot.png --window --padding 20 \
  --font.family "JetBrainsMono Nerd Font Mono"

$CTRL kill -s demo
```

## GIFs from asciinema casts (agg)

```bash
agg --theme dracula --font-family "JetBrainsMono Nerd Font Mono" \
  recording.cast output.gif
```

## Gotchas

**Font family must match an installed font.** The default `"JetBrains Mono,Fira Code,SF Mono,Menlo,..."` won't match Nerd Font variants. Check installed fonts with `fc-list :mono family | sort -u` and use the exact name. Wrong font = broken box-drawing characters (right borders floating mid-line).

**Don't use `--language ansi` with freeze.** Use `--execute` to run the capture command directly — freeze handles ANSI natively via `--execute`. Passing `--language ansi` treats escape codes as syntax tokens, not terminal output.

**Use `dracula` theme for agg**, not `monokai`. ANSI color 90 (bright black / `borderColor="gray"`) is invisible in monokai but visible in dracula (`#6272A4`). This matters for Ink TUI apps that use gray borders.

**freeze `--execute` vs piping.** Both work, but `--execute` is simpler and avoids issues with pipe buffering:
```bash
# Preferred
freeze --execute "tmux capture-pane -t $SESSION -p -e" --output out.png

# Also works (no --language flag!)
tmux capture-pane -t $SESSION -p -e | freeze --output out.png
```
