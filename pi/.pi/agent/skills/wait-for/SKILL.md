---
name: wait-for
description: Block execution until a condition is met. Use when waiting for pipelines, merge trains, deployments, file creation, or any event that can be checked with a shell command.
---

# Wait For

Poll a command until it exits 0 (condition met), returns the fail code (failed
early), or the timeout is reached. Set the `bash` tool's `timeout` ~30s higher
than `--timeout` as a safety net.

```bash
./scripts/wait-for.sh "<command>" [--timeout N] [--interval N] [--fail-code N]
```

- The command is a single quoted string, evaluated by the shell (pipes/quotes
  work).
- `timeout` and `intervals` are number of **seconds**
- `--fail-code N`: exit code meaning "failed" — stop and return N (its stderr is
  surfaced). Use it for checks that can detect failure before the timeout.
- Exit codes:
  - `0` condition met
  - `1` timed out
  - `64` usage error
  - `N` the command returned your `--fail-code` (propagated as-is).

```bash
./scripts/wait-for.sh "test -f /tmp/done.flag" --timeout 120 --interval 5
./scripts/wait-for.sh "curl -sf https://example.com/health" --timeout 60 --interval 5
```

## Wait for a pipeline

Compose `wait-for.sh` with `pipeline-succeeded.sh` (exits 0 succeeded, 1
running, 2 failed — failed jobs on stderr).

**Run from the git repo** (so `glab` finds the project) **and use absolute
paths** (the scripts live in the skill folder). `wait-for.sh` passes its
working directory through to the check, satisfying both:

```bash
SKILL="$HOME/.pi/agent/skills/wait-for/scripts"

# latest pipeline for the current branch
"$SKILL/wait-for.sh" "$SKILL/pipeline-succeeded.sh" \
  --timeout 600 --interval 30 --fail-code 2

# a specific pipeline (URL trailing number, or bare ID)
"$SKILL/wait-for.sh" "$SKILL/pipeline-succeeded.sh <url_or_id>" \
  --timeout 600 --interval 30 --fail-code 2
```

Result: exit 0 = succeeded, 2 = a required job failed (jobs listed on stderr),
1 = timed out.
