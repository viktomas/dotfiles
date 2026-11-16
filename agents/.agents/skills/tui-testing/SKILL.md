---
name: tui-testing
description: Run an interactive CLI/TUI app on a PTY, send input, and capture its screen via the spookys wrapper (spooky-check). Use when you need to exercise an interactive terminal app — testing it, driving its prompts, or capturing what it renders. Keywords - spooky, spookys, terminal, pty, send keys, capture screen.
---

# Testing Interactive CLI Applications

`spookys` drives an app through [spooky-check](https://gitlab.com/viktomas/spooky-check): a real
PTY rendered by Ghostty's VT engine (libghostty-vt), so the screen state is what a terminal
actually shows. Killing a session kills the child's whole process group, so wrapped launches
leave no orphans.

```bash
SP=/Users/tomas/.agents/skills/tui-testing/scripts/spookys
S=test                                        # session name

# start the app (80x24 default; --cast records an asciinema-replayable .cast)
$SP new "$S" -x 200 -y 50 [--cwd DIR] [--cast run.cast] -- your-command --args

$SP ls                                        # list sessions
$SP send "$S" 'hello world'                   # type text
$SP key  "$S" Enter                           # special keys, tmux-style names:
$SP key  "$S" C-c Escape BSpace Down Up Left Right PgUp PgDn Home End Tab F5 M-x
$SP paste "$S" 'multi
line text'                                    # bracketed paste
$SP signal "$S" SIGINT                        # signal the child directly
$SP screen "$S"                               # visible screen as text
$SP screen "$S" -b                            # with scrollback
$SP vt "$S"                                   # screen with ANSI styles (capture-pane -e)
$SP resize "$S" 120 40                        # resize the terminal
$SP watch "$S"                                # read-only live mirror, Ctrl-C to stop
$SP kill "$S"                                 # kill the app + session, clean up
$SP dir  "$S"                                 # session dir: out.log (replies/events), err.log
```

Wait for a pattern:

```bash
until $SP screen "$S" | grep -q 'ready'; do sleep 0.3; done
```

`spookys` requires `jq` and the `spooky` binary — found via `$SPOOKY_BIN`, `PATH`, or a local
build at `~/workspace/gl/spooky-check/zig-out/bin/spooky` (the wrapper fails fast with a clear
message if none is found). The binary ships for linux-x64, linux-arm64 and darwin-arm64.

## Notes

- A blank screen means "still initializing", not "crashed" — heavy TUIs take seconds to first
  paint. Poll the app's own log or the screen; `screen` returning a reply means spooky is alive.
- `send`/`key` only *enqueue* bytes; the reply means accepted, not reacted-to. Wait on the
  screen for the app's response.
- `watch` mirrors the screen read-only; there is no interactive attach. For a replayable record
  start the session with `--cast FILE` and play it with `asciinema play FILE`.
- `watch` ignores SIGINT if the script itself was started in the background from a
  non-interactive shell (inherited-ignored signal) — stop it with `kill -TERM` in that case.
- `kill` (and spooky dying) takes the whole child process group with it — no orphan caveat.
  Only grandchildren that daemonize with `setsid` escape.
- Sessions live in `~/.cache/spookys/<name>/` (`SPOOKYS_DIR` overrides). Dead sessions are
  removed by `kill`; `ls` shows them as `dead`.

This skill no longer uses tmux. If a task explicitly asks for tmux, drive it directly with
`tmux new-session -d` / `send-keys` / `capture-pane` — no skill needed.
