---
date:        2026-11-13
session/ref: task zellij-0-46-onl-3xyea (zellij 0.46-only support)
symptom:     TogglePaneFrames keybinds drifted on zellij 0.46 — Ctrl y
             showed nothing, Esc brought the border, the pane-mode frame
             indicator was unreliable (3-state cycle since 0.45)
evidence:    zj46-frames investigation (/tmp/tasks/prompts/
             zj46-frames-report.md): screen.rs cycles Full→Titles→None→Full
             since 0.45, default Titles, single-pane tab draws Titles ==
             None; verified on this machine that 0.46 keybinds
             SetPaneFrameStyle "full"/"none" are deterministic (3× full
             verify runs: 5 Ctrl y/esc cycles each, every exit key incl.
             CSI-u Ctrl J/K, border read via list-panes geometry 118↔120)
cause:       on/off toggle assumption baked into every mode keybind
fix type:    code
fingerprint: togglepaneframes-3-state-drift
count:       1
---

Fix applied (working tree, not committed): every binding that contained
TogglePaneFrames now sets an explicit style — `SetPaneFrameStyle "full"`
when entering pane mode from normal, `SetPaneFrameStyle "none"` on every
return to normal (esc, enter, space, Ctrl J/K, n, Ctrl n, action keys,
renametab enter). Baseline stays `pane_frames false`; a bare
`pane_frame_style "none"` is NOT equivalent — zellij 0.46's
`PaneFrameStyle::from_options` maps it to Titles (upstream quirk,
options.rs:145). The pane-mode `z` (manual frame hide) was removed: a
deterministic set-only action cannot toggle; esc + Ctrl y restores the
indicator. Two pre-existing indicator leaks were also fixed (pane `/` and
scroll `e` exited to normal without clearing the border — on 0.44 they
left frames on in normal mode too).

Testing notes for the future:
- `zellij --session <nonexistent> action list-panes` exits 0 — don't use
  it to poll for session readiness; the attach client is also later than
  the server (list-clients >1 line).
- zellij 0.46's session index (~/Library/Caches/.../session_index.sqlite)
  is GLOBAL across ZELLIJ_SOCKET_DIR values: `list-sessions` from a
  scratch socket dir shows his live sessions as "EXITED" (their sockets
  aren't there), and `delete-session <hex-id>` from the scratch dir
  deletes their session-info cache folders (self-heals: running servers
  re-serialize; verified his sessions survived). Scratch-server cleanup:
  SIGTERM is ignored, kill -9 the `zellij --server /tmp/<scratch>` pids.
- tmux `send-keys C-J` cannot produce ctrl+shift+j; zellij parses kitty
  CSI-u unconditionally, so send the raw sequence (`\e[74;6u` for
  Ctrl+Shift+J) to exercise those bindings.
- On this host tmux `capture-pane` cannot see zellij's rendering at all;
  read UI state via `zellij action list-panes -a -j` geometry (content
  120↔118 columns = borderless↔full border) and `dump-screen`.
