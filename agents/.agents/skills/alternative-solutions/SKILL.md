---
name: alternative-solutions
description: Deep opt-in MR check - challenge the MR's design with 3 alternative solutions a blind subagent proposes from the requirements alone, including a minimal subset that cuts requirements. Use when asked to challenge the solution, find alternative designs, question the design, or reduce an MR's complexity.
---

# Alternative solutions

Deep opt-in check, triggered **on demand** — never part of the default review
flow. Run it inside an MR review session (e.g. at the post gate) or from any
session with repo + GitLab access. Its output is intelligence for
@viktomas: it is written to the review file (the file printed by `task state`,
same format as `/review-to-post`) as a never-posted section, never as an MR
comment. If no review file exists, report in the final message.

## "Is this the best design, and what can we cut?"

1. **Extract requirements** from the linked issue(s) and the MR description —
   requirements and constraints only (platform, integrations, performance),
   never from the diff.
2. **Blind subagent** (subagent skill): `--model opus --timeout 900`.
   - It must not learn the MR exists. Give it: the problem statement, the
     requirement list, constraints, the repo path, and the **target branch
     ref** (e.g. `origin/main`).
   - Run it from the repo's **canonical checkout** (see the `projects` skill
     for local roots), never from the MR worktree — the worktree contains the
     solution.
   - Put these blindness rules in the prompt verbatim: *read code only via
     `git show <target_ref>:<path>` and `git ls-tree <target_ref>`; do not read
     the working tree, other branches, MR refs, or feature-branch history; do
     not search GitLab for MRs.*
   - Ask for exactly **3 solutions**, each with a rough complexity estimate and
     tradeoffs. One must be a **minimal subset**: which requirements could be
     cut to significantly reduce complexity, and what breaks if they are.
3. **Compare** each of the 3 with the MR's actual design: matches / MR beats
   it / it beats the MR. Flag requirements the MR satisfies that nobody
   asked for. Verdict: MR design is among the best | a much simpler subset
   exists | a materially better design exists — plus the concrete question
   for the author.

Record the 3 solutions, the comparison, and the verdict under
`## Solution validation`.

## Output rules

- The section is never posted and never becomes a finding; it carries across
  refresh and re-review runs unchanged.
- If drafts already exist at the post gate, posting them stays fine — the
  verdict does not block anything. Flag in the final message which draft
  findings the verdict makes moot.
- End with `GATE: reply - <one-line verdict>` when invoked standalone;
  mid-review, keep the session's existing gate.
