---
name: debug-workflow
description: Walk a workflow step-by-step, identify gaps between spec and reality, and spawn tasks to fix them
disable-model-invocation: true
---

# Debug Workflow Skill

Triggered by `/skill:debug-workflow`. Used to systematically walk through a workflow, spot where reality diverges from the spec, and create tasks to close gaps.

## When to use

- User says `/skill:debug-workflow` or "debug this workflow"
- User says "that was wrong" or "this isn't working right" during a workflow
- User wants to improve how the agent handles a specific workflow

## What you do

### Starting a debug session

1. **Read `journey.md`** at the project root — this is the master workflow spec
2. **Identify the relevant workflow** from what the user is doing or asking about:
   - If the user specifies one (e.g. `/skill:debug-workflow refresh`), use that
   - If it's clear from context (e.g. user just asked for a status update → "Refresh + Status Update")
   - If ambiguous, ask the user which workflow to debug
3. **If no matching workflow exists** in `journey.md`, offer to build one collaboratively:
   - Walk through what the user is doing step by step
   - Document each step as you go
   - At the end, add the new workflow to `journey.md`

### Walking the workflow

4. **Determine current step** — from task state, recent agent actions, or ask the user
5. **Present the next expected step** from the journey spec
6. **Execute the step** and observe the result
7. **Compare reality to spec** — did the step produce the expected state change?
   - If yes → move to the next step
   - If no → identify the gap (see below)
8. **Repeat** until the workflow is complete or the user stops

### When something goes wrong

When reality diverges from the spec, identify what type of gap it is:

| Gap Type | Example | Fix Location |
|----------|---------|--------------|
| Missing automation | Agent doesn't auto-run `task list` during refresh | `AGENTS.md` instructions or skill file |
| Wrong agent behavior | Agent shows non-actionable items in status | `AGENTS.md` instructions or calibration examples |
| Missing skill instruction | Review skill doesn't mention setting task to waiting | Skill `.md` file |
| Missing journey step | Workflow doesn't cover edge case | `journey.md` |
| Script bug | `refresh.sh` doesn't archive correctly | Script code |
| Missing script | No automation for a manual step | New script |

For each gap found:

1. **Describe the gap** concisely to the user
2. **Propose a concrete fix** — which file to edit, what to add/change
3. **Create a task** with the `wf:` prefix:
   ```bash
   task new "wf: <description of fix>"
   ```
4. **Log the gap** in the task description with:
   - Which workflow step failed
   - What was expected vs what happened
   - The proposed fix (file + change)

### When the user says "that was wrong"

1. Ask what specifically was wrong (if not obvious)
2. Map it to a journey step — which step produced the wrong result?
3. Identify the root cause (wrong instructions, missing step, script bug)
4. Create a `wf:` task with the fix
5. If the journey spec itself is wrong, update `journey.md` immediately

## Task naming convention

All tasks spawned from debug sessions use the `wf:` prefix:

```
wf: wire refresh output into task status updates
wf: add calibration example for non-actionable items
wf: update review skill to set task waiting after posting
```

This makes workflow improvement tasks identifiable in `task list`.

## Example session

```
User: /skill:debug-workflow refresh
Agent: Reading journey.md... Found "Refresh + Status Update" workflow (7 steps).
       Let me walk through it. Step 1: run scripts/refresh.sh --hierarchical
       [runs it]
       ✅ Step 1 complete — MR files updated, 2 archived.
       
       Step 2: run task list
       [runs it]
       ✅ Step 2 complete — 3 doing, 2 waiting tasks.
       
       Step 3: reconcile tasks against fresh data...
       ❌ Gap found: task "review-prompt-history" is waiting but the MR shows
       new commits from the author (feedback addressed). Should surface as
       action item, but I almost missed it because I only checked merge state.
       
       Creating task: "wf: check for new commits on waiting review tasks"
       
       Continuing with corrected behavior...
```

## Rules

- **Never skip the journey.md read** — always start from the spec
- **One gap = one task** — don't bundle multiple fixes into one task
- **Fix the spec first** — if journey.md is wrong, update it before creating fix tasks for downstream files
- **Be specific in task descriptions** — include the file path and what to change, not vague "improve X"
- **Don't over-create tasks** — if the fix is a one-line edit and the user agrees, just make the fix directly and note it in the journey
