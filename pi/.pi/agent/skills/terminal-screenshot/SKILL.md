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

### Driving a TUI to a state first

Use the **tmux-cli-testing** skill's helper (`tmux_test_helper.sh`) to drive the app to
the desired state, then snapshot the same tmux session. This is the one harness for
driving TUIs over tmux — don't introduce a separate one.

```bash
source path/to/tmux-cli-testing/scripts/tmux_test_helper.sh
trap cleanup_test EXIT

start_test --cwd "$PROJECT" node app.js   # helper creates session $TMUX_SESSION
wait_for "Ready" 30
sleep 1

# Navigate to the screen you want to capture
send_line "some input"
wait_for "Expected output" 15
sleep 1

# Capture the helper's session ($TMUX_SESSION)
freeze --execute "tmux capture-pane -t \"$TMUX_SESSION\" -p -e" \
  --output shot.png --window --padding 20 \
  --font.family "JetBrainsMono Nerd Font Mono"
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
