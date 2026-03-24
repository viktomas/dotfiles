---
name: task-session-context
description: Detects the active task from the TASK_ID environment variable. Use whenever the user says "the task", "this task", "my task", or asks what to work on — check TASK_ID first to identify which task they mean.
---

# Task Session Context

## How It Works

Each pi session may run inside a task-linked zellij session. The environment variable `TASK_ID` identifies the active task.

## When the User Says "The Task"

1. Read `TASK_ID` from the environment: `echo $TASK_ID`
2. If set, run `task show <TASK_ID>` to get the task details (uses the `task` CLI from `/Users/tomas/workspace/gl/work`)
3. The task file contains the description, status, references, and log — this is what the user is talking about
4. If `TASK_ID` is unset or empty, ask the user which task they mean

## Key Points

- `TASK_ID` is the **default context** — when the user says "what should we do" or "the task", they mean this one
- The task file is in `/Users/tomas/workspace/gl/work/tasks/<TASK_ID>.md`
- Related MR/issue files are referenced in the task body (often as absolute paths to `/Users/tomas/workspace/gl/work/mrs/` or `issues/`)
- Use `task` CLI for status changes: `task start`, `task wait`, `task done`, `task log`
