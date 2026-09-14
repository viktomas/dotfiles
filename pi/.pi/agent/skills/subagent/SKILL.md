---
name: subagent
description: Spawn a one-shot subagent in a separate session to investigate or research something without polluting the main context. Use when answering a quiestion obviously doesn't need your current full context.
---

# Subagent

Run a headless `pi` for work that need not live in the main conversation. The
subagent has its own context; its final answer is the script output.

## Invocation

```bash
~/.pi/agent/skills/subagent/scripts/subagent.sh --mode <model> --slug <slug> "<task>"
```

- `--slug <slug>` — short descriptive id, `[a-z0-9-]` only (e.g. `lsp-auth`).
  Becomes the session id `sub-<slug>` and the display name.
- `--model <model>` — optional, defaults to `claude-sonnet-5`.
  - `accounts/fireworks/routers/glm-5p3-fast` - use fast glm5.3 for analysis unless user explicitely said they are away from keyboard, then use sonnet
  - `claude-sonnet-5` use sonnet for implementation and slower analysis
  - `claude-opus-5` use opus for complex subtask delegation where it's expected to resolve higher uncertainty
- `--timeout <seconds>` — optional, defaults to `600`. Raise it for long
  investigations; the run is killed when it expires.
- prompt — positional, or piped on stdin for long multi-line tasks:

```bash
echo "$long_prompt" | ~/.pi/agent/skills/subagent/scripts/subagent.sh --slug lsp-auth
```

A `Warning: No project session found with id ...; creating a new session` line on
stderr is expected and harmless.

## Parallel research

Independent **research** subagents may run in parallel. Do **not** parallelize
subagents that modify files — run those one at a time.

```bash
S=~/.pi/agent/skills/subagent/scripts/subagent.sh
$S --slug topic-a "Question A" > /tmp/sub_a.txt 2>&1 &
$S --slug topic-b "Question B" > /tmp/sub_b.txt 2>&1 &
wait; cat /tmp/sub_a.txt /tmp/sub_b.txt
```

## Debugging a hung or failed subagent

On failure the script prints the exit reason and the session file path to stderr.
Inspect that transcript — the last entry is the step it hung on:

```bash
F=$(ls -t ~/.pi/agent/subagent-sessions/*sub-<slug>.jsonl | head -1)

# timeline: role / tool calls, no bulky text
jq -rc 'select(.type=="message") | [.timestamp, .message.role,
  ((.message.content[]? | select(.type=="toolCall") | .name) // "-")] | @tsv' "$F"

# full detail of the last few entries
tail -3 "$F" | jq .
```

While a subagent is still running you can watch it live with `tail -f` on the
same file.

To browse subagent sessions on purpose (they are kept outside
`~/.pi/agent/sessions/`, so they never show up in `/resume` or `pi -r`):

```bash
pi -r --session-dir ~/.pi/agent/subagent-sessions
```

## Implementaion details (ignore unless debugging)
Subagent `pi` runs without extensions and with only the shared skills (`~/.pi/agent/skills-shared`), so it
cannot spawn further subagents or touch task memory.

The script hardcodes the session dir, the isolation flags and `--`, and wraps the
run in `timeout` so it can never hang forever.