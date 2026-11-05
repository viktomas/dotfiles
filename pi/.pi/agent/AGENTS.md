My GitLab username is @viktomas.

## End every final message with a marker line

When `$TASK_ID` is set, the last line of your final message tells my attention queue
what you need from me. Make it exactly one of:

- `GATE: <kind> - <what I must do, one line>`. Kinds: `reply` (answer a question),
  `decide` (pick between options), `review` (look at your work), `post` (publish
  drafted comments), `merge`.
- `FAILED: <why>`: you're stuck and need me to re-prompt.
- `DONE: <what>`: finished, nothing for me to do. You leave the queue.

If you leave it out, the task extension asks you for it before the turn ends.

## Task state is your memory

When `$TASK_ID` is set, the file printed by `task state` is your only memory for
the task across sessions. Read it first if it exists, and bring it up to date
before your final message. Details: the `task-management` skill.

The **current prompt outranks the state file.** If the two disagree — the state
records a different objective, or names a report/file the prompt doesn't need —
say so in one line, record the redirect at the top of the state file, and get to
work. Never spend turns hunting for artifacts the stale state references; they
are not needed to do what you were just asked.

## Forbidden Git Operations
These commands can destroy your's other agents' work
- `git reset --hard` - destroys uncommitted changes
- `git checkout .` - destroys uncommitted changes
- `git clean -fd` - deletes untracked files
- `git stash` - stashes ALL changes including other agents' work
- `git add -A` / `git add .` - stages other agents' uncommitted work
- `git commit --no-verify` - bypasses required checks and is never allowed
- `git commit` - don't commit unless asked


You can only use them on direct user request.

## Git Interactive Commands

Commands like `git rebase --continue`, `git merge --continue`, and `git commit` open an editor and hang when run non-interactively. Always prefix with `GIT_EDITOR=true` to auto-accept the default message:

```bash
GIT_EDITOR=true git rebase --continue
GIT_EDITOR=true git merge --continue
```

## Orbit

Code search, code reading, GitLab reading and graph queries go through the
`orbit` skill's `glab orbit` commands (`grep` / `context` / `query`) — not
grep/rg or raw `glab api` — because the graph sees what they can't. Load the
skill for syntax and rules.

(Replaces the auto-generated `glab orbit setup` block — if setup re-adds it,
prune again and consider `glab orbit uninstall`.)
