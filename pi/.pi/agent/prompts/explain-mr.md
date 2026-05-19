---
description: Explain MR in 5 snippets
argument-hint: "[command to get the change]"
---
Gather the context about the change if you haven't already. If the instruction is not provided and the change isn't obvious, default to `git diff`.

Instruction on how to get the change: `$@`

Pick 5 code snippets that explain this change the best, then explain the MR using these 5 snippets. I don't expect to get a full understanding, but enough to be able to undrestand the full diff myself later.

Then generate html report with the result, build the whole storry around those 5 snippets, but also use diagrams and summaries for more context.
