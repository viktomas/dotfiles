#!/usr/bin/env bash
# Render a file in the real nvim, in a real terminal, and dump what was painted.
#
#   capture.sh <file> [top-line] [lua-file]
#
# Writes the pane (with SGR escape sequences intact) to stdout. Pipe it to
# decode.py. The optional lua file is sourced after the buffer loads, which is
# how you produce a "before" capture without editing the config.
set -euo pipefail

FILE=${1:?usage: capture.sh <file> [top-line] [lua-file]}
LINE=${2:-1}
LUA=${3:-}
SESSION="nvim-theme-capture-$$"
WAIT=${CAPTURE_WAIT:-14}   # seconds to let the LSP attach and send semantic tokens
COLS=${CAPTURE_COLS:-190}
ROWS=${CAPTURE_ROWS:-45}

EXTRA=""
[ -n "$LUA" ] && EXTRA="-c 'luafile $LUA'"

tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS"
tmux send-keys -t "$SESSION" \
  "TERM=xterm-256color nvim $EXTRA -c 'normal! ${LINE}Gzt' '$FILE'" Enter
sleep "$WAIT"
tmux capture-pane -t "$SESSION" -e -p
tmux kill-session -t "$SESSION" 2>/dev/null || true
