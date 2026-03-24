---
name: wait-for
description: Block execution until a condition is met. Use when waiting for pipelines, merge trains, deployments, file creation, or any event that can be checked with a shell command.
---

# Wait For

Poll a shell command until it exits 0 or a timeout is reached. Uses the `bash` tool's `timeout` parameter to block agent execution.

## Usage

```bash
scripts/wait-for.sh <command> [timeout_seconds] [poll_interval_seconds]
```

- **command** — shell command/expression to evaluate (quoted). Succeeds when exit code is 0.
- **timeout_seconds** — max wait time (default: 300)
- **poll_interval_seconds** — sleep between attempts (default: 10)

Exit codes: `0` = condition met, `1` = timed out, `2` = usage error.

## How to Call

Always set the `bash` tool's `timeout` parameter ~30s higher than the script timeout, as a safety net:

```
bash tool call:
  command: /path/to/scripts/wait-for.sh "<check_command>" <timeout> <interval>
  timeout: <timeout + 30>
```

## Examples

### Wait for MR pipeline to finish (5 min, poll every 30s)

**⚠️ Prefer the early-failure variant below** — a pipeline stays `running` even when required jobs have already failed.

```bash
scripts/wait-for.sh "glab mr view 2941 -R gitlab-org/editor-extensions/gitlab-lsp -F json | jq -e '.pipeline.status == \"success\" or .pipeline.status == \"failed\"'" 300 30
```

### Wait for MR pipeline with early failure detection (recommended)

Detects failure as soon as any non-allow_failure job fails, instead of waiting for the whole pipeline to finish. Requires the pipeline ID — get it from `glab mr view <iid> -F json | jq .pipeline.id`.

```bash
scripts/wait-for.sh "glab mr view 2941 -F json | jq -e '.pipeline.status == \"success\" or .pipeline.status == \"failed\"' 2>/dev/null || glab api 'projects/:id/pipelines/<PIPELINE_ID>/jobs?per_page=100' | jq -e '[.[] | select(.status == \"failed\" and .allow_failure == false)] | length > 0'" 600 30
```

After this returns, check `glab mr view <iid> -F json | jq .pipeline.status` — if it's not `success`, inspect failed jobs.

### Wait for MR to be merged (10 min, poll every 30s)

```bash
scripts/wait-for.sh "glab mr view 2941 -R gitlab-org/editor-extensions/gitlab-lsp -F json | jq -e '.state == \"merged\"'" 600 30
```

### Wait for a merge train pipeline (10 min, poll every 60s)

```bash
scripts/wait-for.sh "glab api 'projects/46519181/merge_requests/2941/pipelines?per_page=1' | jq -e '.[0].status == \"success\"'" 600 60
```

### Wait for a file to appear

```bash
scripts/wait-for.sh "test -f /tmp/build-done.flag" 120 5
```

### Wait for HTTP endpoint to be healthy

```bash
scripts/wait-for.sh "curl -sf https://example.com/health" 60 5
```

## Tips

- The command's stdout/stderr are suppressed during polling — only the exit code matters.
- Progress is printed to stdout so you can see attempt counts and elapsed time.
- For commands with quotes, use escaped quotes inside the outer quotes or use single-quote wrapping.
- Pick a poll interval proportional to the expected wait: 5s for fast checks, 30-60s for CI pipelines.
