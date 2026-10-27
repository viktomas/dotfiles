---
name: task-tabs
description: Inspect and drive the zellij tabs inside task sessions — see what is open and running in each task, read a pane's screen, suggest tabs or sessions to close, open new tabs, run commands in existing tabs. Use when the user asks what's open or running in a task, wants to tidy up tabs or sessions, or wants something started or typed into another task's session. Keywords - tabs, panes, zellij, close tabs, clean up sessions, open a tab, run in that tab, what's running.
---

# Task Tabs

Every task runs in a zellij session named `ts-<task-id>` (the prefix comes from `$TASK_SESSION_PREFIX`). This skill works on the **tabs and panes inside those sessions**. Creating, finishing and switching tasks is the `task-management` skill's job.

Everything goes through one script, which handles the zellij quirks for you:

```bash
T=~/.agents/skills/task-tabs/scripts/tabs.sh

$T ls                       # every live task session: tabs and panes, grouped by task
$T ls -v [<id>...]          # the same, plus the last 4 screen lines of every pane
$T agents [-n 3] [<id>...]  # every pi pane: WORKING / ASKING / IDLE + the tail of its last message
$T peek <id> [<pane>] [-n 40] [--full]   # read one pane (--full includes the scrollback)
$T new <id> [-n name] [-c cwd] [-- cmd]  # open a tab; cwd defaults to the task's cwd
$T run <id> <pane> <text>   # type a line and press Enter, then print the pane's screen
$T keys <id> <pane> "Ctrl c"             # raw keys: Enter, Esc, "Ctrl c", Up, ...
$T close <id> <tab-id>      # close a tab (the script refuses to close the last one)
```

A `<pane>` is `terminal_N` or just `N`. A `<tab-id>` is the stable number after `tab` in the `ls` output, not the tab's position.

## Reading `ls`

```
## ls-arch — doing · work · ls arch  [attached]
  tab 12 "gitlab-lsp/arch-auto-doc"
    terminal_133  ~/w/g/g/arch-auto-doc
  tab 15 "gitlab-lsp/arch-move-drop (pi)"
    terminal_189  π - arch-move-drop
```

- `[attached]`: the user has this session on screen right now. Anything you do there happens in front of them.
- `← this session`: the session you are running in. Your own pane is `terminal_$ZELLIJ_PANE_ID`. Never close it and never type into it.
- `(no task file — orphan session)`: a `ts-*` session with no task behind it, left over from a deleted or archived task.
- The pane title tells you what the pane is:
  - `π - <dir>` is a pi agent.
  - `vim …` is an editor.
  - A bare path is a shell sitting at its prompt.
  - `cmd:` shows the command the pane was started with, when zellij knows it.
- The title only tells you what the pane *is*. `peek` tells you what it is *doing*. Read the screen before you claim a pi is idle or a shell is free.

## What are my agents doing?

`$T agents` is the cheap way to see which pi agents are waiting on the user. It reads each pi pane's screen and classifies it:

- `WORKING`: pi's `── Working ──` bar is showing, so a turn is in progress.
- `ASKING`: the turn is finished and the final message ends in `?`. The user is the blocker.
- `IDLE`: the turn is finished with no question. Read the tail to decide whether it reports something the user needs to see.
- `UNKNOWN`: the screen didn't parse (pi might be showing a selector or dialog). `peek` it.

Only the visible screen is read, so a long final message shows just its last lines. `peek <id> <pane> -n 40` gives more, and `--full` includes the scrollback. The `/dashboard` prompt uses `agents` to put "review done, asks to post comments" on the relevant items.

## Suggesting what to close

Only ever **suggest**. Closing a tab kills whatever is running in it, including unsaved vim buffers and pi conversations. Close nothing until the user has approved specific items.

1. Run `$T ls -v` once, then `peek` any pane whose 4 lines aren't enough to judge.
2. Cross-check with `task list --json`. A task's `agents` map shows which pi processes are `working` right now.
3. Present a short table: task, tab, what's in it, why it can go. Give every candidate a number so the user can reply "close 1, 3, 4".

Good candidates to close:

| Signal | Why it can go |
|---|---|
| Pane `[EXITED]` | The command ended; the tab is dead weight |
| A shell at its prompt whose scrollback shows nothing worth keeping | Nothing to lose |
| A second or third `vim` / `pi` tab in the same directory | Duplicates |
| A pi whose last output is a finished handoff or summary, with another pi tab in the same task | Old conversation |
| A `Tab #N` tab (never named) holding an idle shell | Usually a stray `Ctrl+t` |
| A worktree tab whose branch has since merged | Its work is done |

Don't close:

- A pi that is `working`, or whose screen shows it mid-turn (a spinner, or a tool still running).
- A vim tab with unsaved changes. `peek` it and look for `[+]` in the status line; if you can't tell, don't close it.
- The last tab of a session. `close` refuses anyway.
- Anything in `← this session` unless the user names it.

Whole sessions are not closed here. For a task that is finished, suggest `task done <id>`; the user runs it or explicitly asks you to. For an orphan session, suggest `zellij delete-session --force ts-<id>`.

Once the user approves, close each approved tab with `$T close`, then run `$T ls <id>` and show the result.

## Opening a tab

```bash
$T new ls-arch -n tests -- npm run test:watch
$T new ls-arch -c ~/workspace/gl/gitlab-lsp/main          # plain fish shell
$T new review-feat-mcp-xd32x -- pi "look at the failing lint job"
```

- The command runs through `fish -c "<cmd>; exec fish"`, the same way `task new --run` starts its tabs. The pane falls back to a shell when the command exits, and `$TASK_ID` is already set in it.
- If the user is `[attached]` to that session, zellij switches their view to the new tab, and the script prints a note saying so. Tell the user.
- Starting a brand-new task is `task new … -b` (the `task-management` skill), not this.

## Running something in an existing tab

- Shell panes: `run` is fine whenever the user asked for it. Check with `peek` first that the shell is at a prompt; otherwise your text lands in whatever is running. `run` waits 1.5s before printing the screen (override with `TABS_SETTLE=5`). For anything longer, `peek` again later, or use the `wait-for` skill with `$T peek … | grep <marker>`.
- pi panes: typing into a pi pane sends a prompt to another agent. Do it only when the user asks you to hand that agent something. If the agent is mid-turn, the text is queued as a steering message.
- vim and other TUIs: don't type into them. The only exception is keys the user dictated (e.g. `$T keys <id> <pane> Esc ":w" Enter`).
- To stop a runaway command: `$T keys <id> <pane> "Ctrl c"`.

## Zellij gotchas (already handled by the script)

These matter if you ever call `zellij` directly:

- `zellij -s <session> action …` targets another session without switching to it. `list-panes -a -j`, `list-tabs -j`, `dump-screen -p`, `write-chars -p`, `send-keys -p`, `close-tab-by-id` and `new-pane` all work on headless sessions.
- **`new-tab` on a session with no attached client creates an empty tab with no pane** (zellij 0.45). The script works around this: it attaches a throwaway client inside a detached tmux session for the duration of the call, checks that a pane appeared, and closes the empty tab if one didn't.
- `list-clients` shows whether anyone is attached. The `active` flag in `list-tabs` is always false from the CLI, so don't rely on it.
- `list-panes` has no working directory. For shells, the title shows the directory; for everything else, `peek`.
