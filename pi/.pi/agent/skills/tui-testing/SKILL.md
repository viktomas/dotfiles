---
name: tui-testing
description: Run an interactive CLI/TUI app in tmux, send it input, and read its output. Use to test interactive apps.
---

# Testing Interactive CLI Applications

Use a detached tmux session to drive any interactive app.

```bash
S=test  # session name

# start the app
tmux new-session -d -s "$S" -x 200 -y 50 'your-command --args'

# send input (text)
tmux send-keys -t "$S" 'hello world' Enter

# send special keys
tmux send-keys -t "$S" Escape
tmux send-keys -t "$S" C-c        # ctrl-c
tmux send-keys -t "$S" Down Down Enter

# read visible screen (add -e to keep ANSI colors)
tmux capture-pane -pt "$S"

# read full scrollback
tmux capture-pane -pt "$S" -S -

# kill the session when done
tmux kill-session -t "$S"
```

## Notes

- Give the app a moment to render before capturing: `sleep 0.5` or poll.
- To wait for a pattern:
  ```bash
  until tmux capture-pane -pt "$S" | grep -q 'ready'; do sleep 0.3; done
  ```
- The user can debug interactively: `tmux attach -t "$S"` (Ctrl+B then D to detach).
- List/clean up: `tmux ls`, `tmux kill-server`.

## Gotchas

- **A blank pane usually means "still initializing", not "crashed".** Heavy TUIs
  can take many seconds to first paint (config/plugin/workspace scans). Poll the
  app's own log file for readiness instead of trusting a fixed `sleep`; a `C-l`
  redraw will not force a paint that hasn't happened yet.
- **Wrapped launches orphan the real process on `kill-session`.** If you start
  the app through a shell wrapper (`sh -c …`, `fish -c …`, `env … node …`),
  `tmux kill-session` may reap only the wrapper and leave the actual child
  running — causing a second live instance, lock contention, or port conflicts
  on the next launch. After killing, confirm it's gone and `pkill -f` the command
  as a fallback:
  ```bash
  tmux kill-session -t "$S" 2>/dev/null
  pkill -f 'your-command --args' 2>/dev/null
  ```
