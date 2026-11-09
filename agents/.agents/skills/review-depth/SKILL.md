---
name: review-depth
description: Deep opt-in checks for an MR review — validate the problem behind an MR (who sanctioned it, internal or external, how it ranks against other work, is the MR needed at all) or challenge the solution (a blind subagent proposes 3 alternative designs from the requirements alone, compared against the MR's design). Use when asked to validate the problem, challenge the solution, question whether an MR is needed, find alternative designs, or cut requirements to reduce complexity.
---

# Review Depth

Two optional deep checks, triggered **on demand** — never part of the default
review flow. Run them inside an MR review session (e.g. at the post gate) or
from any session with repo + GitLab access. Their output is intelligence for
@viktomas: it is written to the review file (the file printed by `task state`,
same format as `/review-to-post`) as never-posted sections, never as MR
comments. If no review file exists, report in the final message.

The two modules are independent; run either or both.

## Module: Problem validation — "is this MR needed at all?"

Cheap (API reads + analysis, no subagent).

1. **Trace requirements.** From the MR description, find the linked issue(s)
   and read them fully, including discussions. Follow the chain: who reported
   the problem → who triaged it → who prioritized it. Note any requirement that
   appears only in the MR description with no issue backing.
2. **Who sanctioned the problem.** Issue author and their role; customer
   signals (ZD ticket refs, customer labels, support escalation); product
   signals (PM/Product labels, epic, milestone); or engineer-initiated.
   Classify: external customer | internal user | team-internal |
   engineer-initiated.
3. **Rank against other problems.** Recent work in
   `/Users/tomas/workspace/gl/work` (`scripts/mr-overview.sh`,
   `issues/`, `archive/`) and `glab orbit query` (e.g. how much recent activity
   the problem's issue/epic has, how many other MRs hang off it). Is this
   problem more or less important than what the team has been doing?
4. **Verdict** — needed / marginal / not needed — one paragraph of evidence,
   plus the exact question to ask the author or team when the verdict is not
   "needed".

Record the verdict and evidence under `## Problem validation`.

## Module: Solution validation — "is this the best design, and what can we cut?"

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

- Sections are never posted and never become findings; they carry across
  refresh and re-review runs unchanged.
- If drafts already exist at the post gate, posting them stays fine — the
  verdict does not block anything. Flag in the final message which draft
  findings the verdict makes moot.
- End with `GATE: reply - <one-line verdict per module that ran>` when invoked
  standalone; mid-review, keep the session's existing gate.
