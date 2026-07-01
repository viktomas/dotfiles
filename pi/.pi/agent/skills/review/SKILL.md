---
name: review
description: code changes review, use this skill any time I ask you to review a change
---

## Preparation

If the working directory contains changes, first make sure if I want to review only the uncommitted changes or the full diff with main.

If the working directory is clean or user wishes to diff with main, find merge base with main and review changes from there.

For context, use the gitlab-api skill to find the MR description and all relevant/referenced issues and MRs, try to get as much context as you can to understand the changes.

Fish for any relevant architecture.md files that are in the same path as changed files. (`fd -i architecture.md`).

Once you have GitLab context, diff and relevant architecture documentation, do a full change review:

## Review output

Lead with a high level explanation of why the MR is need and how it achieves the goal.

Then show me five key snippets that support best the story of the MR and explain how key parts work.

Identify places with the highest complexity (see dedicated section)

Then give me a list of issues that match the following critiria and in the format according tho the following guidelines

## Issue criteria

Report issues that:

1. Meaningfully impact the accuracy, performance, security, or maintainability of the code.
2. Are discrete and actionable (not general issues or multiple combined issues).
3. Don't demand rigor inconsistent with the rest of the codebase.
4. Were introduced in the changes being reviewed (not pre-existing bugs).
5. Don't rely on unstated assumptions about the codebase or author's intent.
6. IMPORTANT: Have provable impact on other parts of the code — it is not enough to speculate that a change may disrupt another part, you must identify the parts that are provably affected.
7. Be particularly careful with untrusted user input and follow the specific guidelines to review.
8. Comments in the code that explain WHAT the code does. I only want comments that explain WHY (reason not already obvious in the code)
9. Unnecessary tests. If a test is duplicate or tests something trivial, let's remove it.

## Untrusted User Input

When you spot a new user input (CLI flag, Input field, URL parameter, Config file), trace where the input is used and if it can affect execution in any way. Always assume that somebody will try to exploit that input, what is the blast radius? Could it be used to run arbitrary code?

- If the input comes from user (e.g. CLI args or global settings in the user directory), it's probably OK that that input can run arbitrary code.
- If the input comes from a project (i.e. loaded from untrusted project settings that could be arbitrary repo on the internet), we cannot let that code trigger arbitrary code without user approval

## Complexity

Be on a lookout for (accidental) complexity. The MR doesn't have to introduce it, it can only contribute to it.

- Could we move some complex algorithm at least partially in datastructures? 
- Flag parts of the code that seem too complex for what the goal/mental model of the logic is.
- Feel free to suggest a partial re-architecture if it clealry simplifies the code.

## Comment guidelines

1. Be clear about why the issue is a problem.
2. Communicate severity appropriately - don't exaggerate.
3. Be brief - at most 1 paragraph.
4. Keep code snippets under 3 lines, wrapped in inline code or code blocks.
5. Use \`\`\`suggestion blocks ONLY for concrete replacement code (minimal lines; no commentary inside the block). Preserve the exact leading whitespace of the replaced lines.
6. Explicitly state scenarios/environments where the issue arises. IMPORTANT: Focus on the impact on the user or app stability
7. Use a matter-of-fact tone - helpful AI assistant, not accusatory.
8. Write for quick comprehension without close reading.
9. Avoid excessive flattery or unhelpful phrases like "Great job...".

## Review priorities

1. Call out newly added dependencies explicitly and explain why they're needed.
2. Prefer simple, direct solutions over wrappers or abstractions without clear value.
3. Favor fail-fast behavior; avoid logging-and-continue patterns that hide errors.
4. Prefer predictable production behavior; crashing is better than silent degradation.
5. Ensure that errors are always checked against codes or stable identifiers, never error messages.

## Priority levels

Tag each finding with a priority level in the title:
- [P1] - Urgent. Should be addressed before merging to main.
- [P2] - Normal. To be fixed eventually.
- [P3] - Low. Nice to have.

---

After the review is done, expect that I'll want you to verify the user impact of the reported P1 and P2 errors, I'll ask you to run the code and reproduce them, but don't do that in the initial review.
