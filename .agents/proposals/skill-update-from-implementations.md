# Proposal: update the agent-scaffolding skill from three landed implementations

Date: 2026-11-09 · task `review-scaffold-m9s9d` · target:
`agents/.agents/skills/agent-scaffolding/` (= `~/.agents/skills/agent-scaffolding`)

Evidence base: the skill's guidelines were applied end-to-end in three repos —
dotfiles (repo-local 2026-11-06 + global scope pass 2026-11-09, 8 commits),
work (2026-11-05→06, phases 0–5 incl. journal tooling + gardener), lifeos
(2026-11-06→09, merged `2fc53a4` + `312ce72`, incl. replay runner + baseline).
Every item below traces to a recorded outcome in one of those `.agents/AUDIT.md`
files or a journal entry. The skill's model held up; these edits add the
operational detail the implementations learned the hard way.

## A. operational-gotchas.md — Skill validator section

**A1. Colon-space rule (dotfiles journal `skill-frontmatter-colon-space`).**
Add after the description bullet:

> **YAML validity.** `: ` (colon+space) inside an unquoted plain-scalar
> description is invalid YAML; the harness then refuses to load the skill and
> headless sessions die before creating a log. Fail on it (suggest ` - `
> instead), or parse frontmatter with a real YAML parser. This class of bug
> surfaces at session start, not commit time, unless the validator catches it.

**A2. Under-length allowlist (dotfiles `global-skills-budget.md` proposal).**
Add to the description bullet:

> An allowlist may exempt pure keyword-trigger skills from the 30-word floor
> when they verifiably fire: under-length costs nothing (the description
> already matches its triggers), over-length is paid every session.

## B. operational-gotchas.md — Eval corpus leakage section

**B1. History leaks, not just files (lifeos Phase 5).** Replace/augment the
"checkout of the base commit" advice:

> Agents read git history. In a repo whose AGENTS.md itself teaches
> `git show <sha>:file`, an early replay case run from a worktree at base found
> the landed solution commit in `git log` within 8 turns. Clone **pruned to the
> base** — delete all refs and the origin remote, then gc — so nothing above
> the base is reachable; history below the base survives and is fine.

**B2. Case prompts must be self-contained and true (lifeos + work).** Add:

> A false premise in a prompt ("in the templ file" when the code lives in
> `run.js`; naming a file that doesn't exist) lets the agent treat a trigger
> case as a lookup and skip the skill — a case-prompt flaw, not a description
> problem. Reword the case, not the description. Terse, natural, and *true*.

## C. operational-gotchas.md — Isolating the agent under test

**C1. Between-case cleanup (lifeos).** Add:

> A case that leaves a fixture server (or an agent-spawned Chrome) running
> trips the next case. Kill them between cases. And never edit a runner
> script while it runs — sh reads incrementally and the edit can crash its tail.

**C2. macOS paths and timestamps (lifeos).** Add:

> On macOS `/tmp` is `/private/tmp`: derive the session-log slug from the
> realpath cwd or every case reports "no session log". The epoch timestamp
> lives in `message.timestamp`; the top-level session timestamp is ISO text.

**C3. Structural, not conventional, isolation (lifeos incident).** Strengthen
the durable-writes bullet:

> An early case run in the real tree edited a source file (reverted). Make
> isolation structural: rsync the working tree (minus `.git`/`.agents`) to a
> throwaway copy per case, and let the runner only ever point at that copy.

## D. operational-gotchas.md — Cost calibration

**D1. Gate/seed split + cumulative guard (lifeos owner decision).** Add:

> A full replay suite can cost far more than expected (7 tasks × 3 runs ≈ $70
> on a fast model). Split the task set: a cheap **gate** set run on every
> scaffolding change (~$11), and an expensive **seed** set measured quarterly
> only. Enforce a cumulative `BUDGET_USD` guard in the runner that stops the
> run once crossed — per-task estimates vary >2×, so the guard, not the
> estimate, is what bounds spend. Order gate tasks cheapest-first so a
> truncation still buys signal.
>
> Seed-refresh guidance: prefer small commits whose acceptance tests exercise
> handler/e2e behavior rather than internal helpers (see F1).

## E. operational-gotchas.md — new "Acceptance design" notes (or fold into a replay section)

**E1. Scope acceptance to the target (lifeos).** Add:

> Old base commits carry time-bomb tests (absolute dates, red for anyone
> later). Scope test selection to the target commit's own packages instead of
> running the whole suite, and verify the green property per task (target +
> scaffold overlay passes) before trusting a red as a fail.

**E2. Acceptance that pins internal APIs makes deterministic 0/3 tasks
(lifeos).** Add:

> If the acceptance tests pin internal symbol names/signatures, agents fail
> with equivalent-but-differently-shaped implementations — deterministic
> 0/3, cost without pass-rate signal. Either accept them as seed-only
> convention signal, or pick commits tested through public behavior.

## F. operational-gotchas.md — new "Guards" section (from work's scaffolding-guard + git-guard)

**F1.** Add a short section after "Hooks in a shared repo":

> **Guard design.**
> - Confirm-to-proceed beats a hard block when the owner often asks for the
>   guarded action on purpose; headless runs (no UI) fail closed with a
>   remediation message instead of wedging.
> - Log every confirm — allowed, declined, or fail-closed — into the session
>   transcript (never sent to the LLM) so false positives can be found by
>   grepping sessions, not by the owner remembering to complain.
> - Resolve absolute tool paths against the session cwd: a guard that only
>   matches repo-relative patterns never sees `.pi/skills/…` edits made by
>   absolute path.
> - Bash-command matching must be pipeline-aware: exempt read-only git
>   stages, count redirects only when the *target* is guarded, require a
>   write-verb to share a pipeline unit with the guarded path, blank quoted
>   text and heredocs before matching.
> - Scratch-test every guard with positive and negative cases (work used 11
>   and 22) before trusting it; guards are heuristics, not sandboxes.
> - When task metadata can't carry a role (a task-category value the harness
>   rejects), an env var (`PI_GARDENER=1`, set by the gardener's launcher)
>   is the workable gardener token.

## G. guidelines.md — small additions

**G1. Phase 0, output paragraph:** add two sentences:

> The plan doubles as the effort's memory across sessions: tick gate results
> inline, resolve owner decisions in place (~~strikethrough~~ + resolution
> date), and end it with a next-agent quickstart naming the first task, the
> open decisions, and the rules of engagement — the next session starts there,
> not by re-reading history.

**G2. Phase 0, inventory step:** add:

> Parent-directory AGENTS.md files ride along in every session of a nested
> repo — measure the whole stack, and record out-of-scope findings (global
> skills, parent files, cross-harness duplicates) in the audit for a dedicated
> later pass instead of fixing them mid-scope.

**G3. Phase 2, budget step:** add:

> A token budget survives provenance tags; a line budget punishes them —
> pick the unit accordingly.

**G4. Phase 5, steps:** fold D1's gate/seed split in as one sentence (cheap
gate set per change, expensive full set quarterly, runner-enforced spend cap).

## What is deliberately NOT changed

- Phase structure, gates, nine-layer table, anti-patterns — all three
  implementations confirm they work as written.
- The skill stays manual-only (`disable-model-invocation: true`): it's needed
  only during gardener passes, and its description would cost tokens in every
  session across all harnesses.
- Trigger-eval methodology (don't tune nothing-loaded-correct cases) —
  followed correctly in all three repos; already in the guidelines.
- Cross-scope shadowing rules — the work-context stub story already matches
  Phase 3 step 4's warning.

## Cost/benefit and revert

Cost: ~1 hour, no eval spend (documentation only; the skill is manual-only
so no session cost changes). Benefit: the next repo's pass inherits $70+
worth of measured lessons instead of re-learning them. Revert: `git revert`
of the single docs commit — one concern, one commit.

Principles applied: 9 (don't store what's re-derivable — these are *not*
re-derivable, they cost real dollars and broken sessions to learn), 7
(provenance: every item cites its AUDIT/journal source), 1 (selection: three
independent implementations recurred on the same patterns).

## Outcome — second opinion applied (2026-11-09)

Second opinion: Opus subagent `sub-skill-update-review-1794231378`
(transcript in `~/.pi/agent/subagent-sessions/`). Verdicts applied:

- **A1 reworded** — rule is "parse frontmatter with a real YAML parser";
  colon-space is the example, not the rule.
- **B1 evidence corrected** — the incident was a case run in the *real tree*
  (runner bug), not a worktree at base; added `git reflog expire` (a clone's
  reflog survives plain gc).
- **B2** attributed to lifeos only; merged into the existing terse-prompts
  bullet as "and *true*".
- **C2** kept the realpath clause, dropped the `message.timestamp` detail
  (pi log trivia, principle 9).
- **C3 + B1 third bullet** — isolation is now structural (runner refuses the
  real repo; rsync copy for triggers, pruned clone for replay) and the
  scaffold under test is **overlaid onto the base** (the review's biggest
  missed lesson: a plain base checkout measures the old scaffolding).
- **D1** — dollar figures moved to the cost table; cap-below-set-cost stated
  as a legitimate owner choice; seed-refresh line absorbed into E2.
- **F1 halved** — kept confirm-to-proceed/fail-closed, transcript logging,
  absolute-path resolution, effect-not-mention, negative-testing; dropped the
  case counts and the `PI_GARDENER` bullet (pi-specific). Phase 4's
  "hook that rejects" amended to allow confirm-to-proceed.
- **G1** cut to one sentence (tick-off was already in Phase 0).
- **G2 extended** — re-verify recorded cross-scope findings before acting
  (the purge-shadowing finding was wrong, the parent-stack one stale).
- **G3 dropped** — no evidence: all three repos used *line* budgets and kept
  provenance out of AGENTS.md. The real lesson (provenance may live outside
  AGENTS.md) went into Phase 2 step 6 instead.
- **G4 expanded** — Phase 5 step 1 now says pruned clone + scaffold overlay.

Missed lessons absorbed: scaffold overlay (above); hook path coverage must
match validator scope + negative-test every check (Guard design); validator
edge cases (fence skip, anchor strip, em-dash word count, manual-only skips
only the description check); `cat`-counts-as-load; provider-outage discard;
absolute home paths break copy sandboxes; stale worktree guards; cross-scope
wrong-skill loads → stop tuning after two failed changes, route to the owning
scope; session logs as usage evidence for retiring skills; symlink-don't-copy
when deduplicating across harnesses; gotchas header re-dated to three repos.

"Deliberately NOT changed" amended by the review: Phase 5 step 1 *was* wrong
(history leak) and Phase 4's reject-hook wording contradicted
confirm-to-proceed — both fixed. Phase structure, gates, nine-layer table and
anti-patterns otherwise confirmed.

Applied as two commits (guidelines / gotchas — separate concerns, independent
revert) plus this decision record.
