---
description: Finalise the code through several rounds of code review
---


## Phase 1: Duo autoamated review
Check if the MR has autoamted Duo review already, if yes, think through every feedback comment, if valid, then implement the fix, commit and comment on the MR comment.

## Phase 2: three review cycles

Read subagent skill and perform the following task 3 times:

- Ask a `claude-opus-4-8` subagent to perform a review. Keep the subagent prompt short and let it read its own `review` skill — do NOT hand it a long checklist of what to look for. Use this exact prompt (substitute the repo path):

  > review the changes on the current branch (range `main..HEAD`), verify and try to reproduce all p1 and p2 errors.

- If the p1/2 findings are valid, fix them, conv commit after each fix
- NEVER amend, ALWAYS add new commits

## Phase 3: Summary

IF you added any commits, generate a temporary report (NOT task report) explaining:

- all p1/p2 fixes, with diffs for most important parts, diagrams and so on
- list all p3/p4 findings with a description of the issue and your estimate of impact/effort/complexity
