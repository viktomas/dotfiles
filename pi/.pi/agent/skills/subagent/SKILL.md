---
name: subagent
description: Spawn a one-shot subagent in a separate session to investigate or research something without polluting the main context. Use when answering a quiestion obviously doesn't need your current full context.
---

# Subagent

Run a headless `pi` for work that need not live in the main conversation. The
subagent has its own context; only its final printed answer comes back to you.

## Invocation

```bash
pi -p --session-dir ~/.pi/agent/subagent-sessions --session-id sub-<slug> \
  -n "subagent: <slug>" --model claude-sonnet-5 "<task for the subagent>"
```

- `-p` — one-shot: run, print the final answer, exit.
- `--session-dir ~/.pi/agent/subagent-sessions` — sessions are kept, but this dir is
  outside `~/.pi/agent/sessions/`, so they never pollute `/resume` or `pi -r`
  (not even the "all sessions" scope). pi has no per-session "hidden" flag, so a
  separate session dir is the way to hide them.
- `--session-id sub-<slug>` — short descriptive id (e.g. `sub-lsp-auth`); the file
  lands in `~/.pi/agent/subagent-sessions/<timestamp>_sub-<slug>.jsonl`.
- `-n "subagent: <slug>"` — display name, so the run is labelled when browsed.

Never use `--no-session`: without a session file a hung or truncated subagent is
undebuggable.

A `Warning: No project session found with id ...; creating a new session` line on
stderr is expected and harmless.

To browse subagent sessions on purpose:

```bash
pi -r --session-dir ~/.pi/agent/subagent-sessions
```

The answer returns as `bash` output. Write a self-contained prompt: the subagent
knows nothing of the main conversation, so include all context and the exact question.

## Parallel research

Independent **research** subagents may run in parallel:

```bash
D=~/.pi/agent/subagent-sessions
pi -p --session-dir $D --session-id sub-a -n "subagent: a" --model claude-sonnet-5 "Question A" > /tmp/sub_a.txt 2>&1 &
pi -p --session-dir $D --session-id sub-b -n "subagent: b" --model claude-sonnet-5 "Question B" > /tmp/sub_b.txt 2>&1 &
wait; cat /tmp/sub_a.txt /tmp/sub_b.txt
```

## Debugging a hung or failed subagent

Run subagents under `timeout` so they can't hang forever:

```bash
timeout 600 pi -p --session-dir ~/.pi/agent/subagent-sessions --session-id sub-x ... "..."
```

Then inspect the session transcript to see where it got stuck — the last entry is
the step it hung on:

```bash
F=$(ls -t ~/.pi/agent/subagent-sessions/*sub-x.jsonl | head -1)

# timeline: role / tool calls, no bulky text
jq -rc 'select(.type=="message") | [.timestamp, .message.role,
  ((.message.content[]? | select(.type=="toolCall") | .name) // "-")] | @tsv' "$F"

# full detail of the last few entries
tail -3 "$F" | jq .
```

While a subagent is still running you can watch it live with
`tail -f` on the same file.

Do **not** parallelize subagents that modify files — run those one at a time.
