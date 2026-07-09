---
name: subagent
description: Spawn a one-shot subagent in a separate session to investigate or research something without polluting the main context. Use when answering a quiestion obviously doesn't need your current full context.
---

# Subagent

Run a headless `pi` for work that need not live in the main conversation. The
subagent has its own context; only its final printed answer comes back to you.

## Invocation

```bash
pi -p --no-session --model claude-sonnet-5 "<task for the subagent>"
```

- `-p` — one-shot: run, print the final answer, exit.
- `--no-session` — ephemeral; not saved to history.

The answer returns as `bash` output. Write a self-contained prompt: the subagent
knows nothing of the main conversation, so include all context and the exact question.

## Parallel research

Independent **research** subagents may run in parallel:

```bash
pi -p --no-session --model claude-sonnet-5 "Question A" > /tmp/sub_a.txt 2>&1 &
pi -p --no-session --model claude-sonnet-5 "Question B" > /tmp/sub_b.txt 2>&1 &
wait; cat /tmp/sub_a.txt /tmp/sub_b.txt
```

Do **not** parallelize subagents that modify files — run those one at a time.
