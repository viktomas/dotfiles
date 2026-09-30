---
description: Review an MR end to end and stop with draft comments ready to post (initial review, re-review, or refresh after new commits)
argument-hint: "<mr-url> [todo:<id>] [extra context]"
---
Review the MR $1 and take it all the way to draft comments that are ready for me to post. ${@:2}

Run every step yourself without asking me. Stop early only for:
- a judgement call you can't settle from the code, the issue or the discussion → `GATE: decide`
- tooling (checkout, `note`, `glab`) failing twice → `FAILED`

**Never publish** unless I explicitly say so (see "When I come back").

## The review file

The unsubmitted review lives in the file printed by `task state`. It is the **source of truth**; the GitLab drafts are a copy of it.

```markdown
---
mr: <mr url>
todo: <todo id, or empty>
reviewed_sha: <full sha the drafts are anchored to>
---
# Review: <MR title>

## Summary
For me and the next agent, never posted. What the MR does, what you checked, the verdict,
and findings you dropped and why (e.g. "the verifier refuted X: Y already handles it").

## [P1] <one-line finding>
location: `<path>:<line>` | general  ← a new diff or MR-level comment, or
reply: <discussion id>               ← a reply on one of my existing threads
draft: <draft note id>               ← filled in by step 6
impact: user-facing | maintenance

<the comment body, exactly as drafted, starting with :robot: AI-generated>

**Verified:** what you ran, how long it took, any setup or temporary code changes. Enough
for a later run to repeat it quickly, or skip it if the code didn't change.

## Notes for the next review
Optional. Things that aren't MR comments: follow-ups, out-of-scope simplifications, issues
to open, what to check when the author responds. Each note says what to check and what to
do for each outcome.
```

A **notes-only file** is the same file with only `# Notes: <MR title>` and the `## Notes for the next review` section: no frontmatter, no Summary, no findings.

## Steps

### 0. Worktree at MR head

Compare `git rev-parse HEAD` with the MR `sha` (`glab mr view -F json`). If they differ and `git pull --ff-only` doesn't fix it, stop with `FAILED: worktree not at MR head`.

### 1. Reconcile the file with the drafts

Skip if the review file has no findings. Otherwise run `note draft list --json` and, for each finding in the file:
- **its `draft:` id is in the list** and the draft body differs from the file → I edited it. Copy my text into the file; it wins from now on.
- **its `draft:` id is not in the list** → I published or deleted it. Remove the finding from the file (published findings live in GitLab threads from now on).

Files written before the `draft:` line existed: match drafts by location or reply target instead.
Drafts that don't start with `:robot: AI-generated` are mine: never edit or delete them.

### 2. Pick the mode

| After step 1, the file… | Mode |
|---|---|
| has findings, `reviewed_sha` = HEAD | **Done.** Run step 6 to confirm drafts match, then the final message |
| has findings, `reviewed_sha` ≠ HEAD | **Refresh**: the author pushed after the drafts were written |
| has no findings (missing, notes-only, or emptied by step 1), and I (@viktomas) have threads on the MR | **Re-review** |
| has no findings, and I have no threads | **Initial** |

If step 1 emptied the file, rewrite it as notes-only first (keep the Notes section, drop the rest).

### 3. Context

Use the `review` skill for gathering context and for the criteria. Read every discussion (`glab mr note list`) and trace the requirements to the linked issue(s).

- **Re-review:** read the notes-only file first, if any. Look at the diff since my last review. For each of my threads decide: addressed, partly addressed, or ignored. Don't re-raise points I already made; draft follow-ups as `reply:` findings. For each note: drop it if resolved, turn it into a finding if the MR should act on it now, otherwise keep it and mention it in the final message.
- **Refresh:** work from `git diff <reviewed_sha>..HEAD` only:
  - finding whose code wasn't touched → keep as is, don't re-verify.
  - finding whose code was touched → repeat its **Verified** reproduction. If fixed, remove it and say so in the final message.
  - new code no finding covers → review just that.

### 4. Review and verify

Initial and re-review: the whole MR. Refresh: only touched or new code.

1. Review following the `review` skill. Tag findings P1/P2/P3.
2. Use the `subagent` skill to spawn a reviewer that doesn't see your reasoning. Ask it to refute each P1/P2 and to look for simplifications you missed. Drop what it refutes (note it in the Summary), add the simplifications you agree with.
3. Reproduce every P1/P2 where it's feasible locally: tests, a small script, or `tui-testing`. This overrides the review skill's "don't reproduce in the initial review". Don't start GDK; if only GDK would confirm it, say so in the comment. Record how in **Verified**.
4. **Leave the worktree clean.** Revert tracked-file changes you made (`git checkout -- <files>`), delete stray untracked files, describe them in **Verified** instead. `git status --porcelain` must be empty, or the next scheduled update of this worktree fails.

### 5. Write the review file

Write the whole file: frontmatter (`todo` from the arguments, else keep the existing value; `reviewed_sha` = HEAD), Summary, one section per finding (comment guidelines from the `review` skill), and the Notes section carried over and extended (e.g. out-of-scope simplifications).

Never write a review summary for GitLab: I write the posted summary myself.

### 6. Sync the drafts to the file

1. `note draft list --json`.
2. Delete (`note draft delete <id>`) every AI draft that is anchored to an older commit or whose finding is no longer in the file.
3. Create a draft, anchored to HEAD, for every finding that has none: `note draft create --json` (`--reply <discussion>` for `reply:` findings, no `--file` for `general`); see the `gitlab-mr-comments` skill, references/DRAFTS.md. Write each returned id into the finding's `draft:` line.

Result: exactly one draft per finding, all on HEAD, and every `draft:` id in the file exists.

## Final message

- One line per finding: priority, location, the finding in one sentence, and reproduced / re-verified / carried over.
- What you dropped or found fixed, what you couldn't verify, and notes I should act on (e.g. "open an issue for X").
- The very last line is exactly one of:
  - `GATE: post - <n> draft comments on <short MR title>`
  - `GATE: post - no findings, ready to approve`
  - `GATE: decide - <the question, one line>`
  - `FAILED: <what broke>`

## When I come back

**"publish" / "post":**
1. `git fetch` and compare with the MR head. If it moved past `reviewed_sha`, run the steps again (it will be a refresh) and show me what changed before publishing.
2. `note draft publish --all`, then check that `note draft list --json` is empty. Stop if it isn't.
3. Mark the review-request TODO done: `glab api -X POST todos/<todo>/mark_as_done` with the file's `todo`. If empty, find my pending `review_requested` TODO for this MR via `glab api 'todos?state=pending&action=review_requested'`.
4. If the file has notes, rewrite it as notes-only; otherwise `rm "$(task state)"`.
5. End with `DONE: published <n> comments`.
