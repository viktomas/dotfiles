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

### Wait for a pipeline with early failure detection (recommended)

Use the dedicated `wait-for-pipeline.sh` script. It returns 0 on success and exits immediately with 1 when any required (non-allow_failure) job fails — no need to wait for the full pipeline. It also prints the failed job names and URLs.

Must be run from a git repo directory so `glab` can resolve `:id`.

```bash
scripts/wait-for-pipeline.sh [pipeline_id] [timeout_seconds] [poll_interval_seconds]
```

If `pipeline_id` is omitted, auto-detects the latest pipeline for the current git branch.

Exit codes: `0` = success, `1` = failed, `2` = usage/detection error, `3` = timed out.

```bash
# Auto-detect pipeline from current branch (default: 10 min, poll every 30s)
scripts/wait-for-pipeline.sh

# Explicit pipeline ID
scripts/wait-for-pipeline.sh 1234567

# Custom timeout and interval
scripts/wait-for-pipeline.sh 1234567 900 60
```

How to call from the agent:
```
bash tool call:
  command: /path/to/scripts/wait-for-pipeline.sh [pipeline_id] <timeout> <interval>
  timeout: <timeout + 30>
```

### Wait for current branch's MR to be merged (10 min, poll every 30s)

Uses current branch name to look up the MR. Run from within the git repo.

```bash
scripts/wait-for.sh "glab mr view \$(git branch --show-current) -F json | jq -e '.state == \"merged\"'" 600 30
```

### Wait for a merge train pipeline (10 min, poll every 60s)

Get the MR iid first: `glab mr view $(git branch --show-current) -F json | jq .iid`

```bash
scripts/wait-for.sh "glab api 'projects/:id/merge_requests/<mr_iid>/pipelines?per_page=1' | jq -e '.[0].status == \"success\"'" 600 60
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
