---
name: problem-validation
description: Deep opt-in MR check - validate the problem behind an MR by tracing requirements to their issue, who sanctioned the problem, and how it ranks against the team's other work. Use when asked to validate the problem, question whether an MR is needed, or check that requirements are issue-backed.
---

# Problem validation

Deep opt-in check, triggered **on demand** — never part of the default review
flow. Run it inside an MR review session (e.g. at the post gate) or from any
session with repo + GitLab access. Its output is intelligence for
@viktomas: it is written to the review file (the file printed by `task state`,
same format as `/review-to-post`) as a never-posted section, never as an MR
comment. If no review file exists, report in the final message.

## "Is this MR needed at all?"

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

## Output rules

- The section is never posted and never becomes a finding; it carries across
  refresh and re-review runs unchanged.
- If drafts already exist at the post gate, posting them stays fine — the
  verdict does not block anything. Flag in the final message which draft
  findings the verdict makes moot.
- End with `GATE: reply - <one-line verdict>` when invoked standalone;
  mid-review, keep the session's existing gate.
