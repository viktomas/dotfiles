---
description: Review an MR end to end and stop with draft comments ready to post (initial review, re-review, or refresh after new commits)
argument-hint: "<mr-url> [todo:<id>] [extra context]"
---
Review the MR $1 and take it all the way to draft comments that are ready for me to post. ${@:2}

Run every step yourself, without stopping to ask me. The only reasons to stop are the final gate, a Decide or a FAILED (see the stop rules).

## The review file (the task's state file)

The unsubmitted review lives in one markdown file: the path printed by `task state` (it uses `$TASK_ID`). This file is the **source of truth**. The GitLab drafts are a copy of it, and I post the review from the drafts. Keep it in this shape:

```markdown
---
mr: <mr url>
todo: <todo id from the arguments, or empty>
reviewed_sha: <full sha of the commit the drafts are anchored to>
---
# Review: <MR title>

## Summary
What the MR does, what you checked, the overall verdict. Findings you dropped and why
(e.g. "the verifier refuted X: Y already handles it").

## [P1] <one-line finding>
`<path>:<line>`

<the comment body, exactly as drafted, starting with :robot: AI-generated>

**Verified:** free text for the next agent: what you ran, how long it took, any setup
or temporary code changes needed. Enough that a later run can repeat it quickly or
skip it if the code didn't change.

## Notes for the next review
Optional. Things that aren't MR comments but a later review should check: follow-up ideas,
out-of-scope simplifications, possible issues to open, what to look for when the author
responds. Each note says what to check and what to do depending on the outcome.
```

Write the file **before** creating drafts, and update it whenever the drafts change.

After publishing, the file shrinks to a **notes-only file**: no frontmatter, no Summary, no `## [P…]`
sections, only `# Notes: <MR title>` and the `## Notes for the next review` section. Published
findings live in the GitLab threads from then on; don't keep copies in the file.

## 0. Pick the mode

- Make sure the worktree is at the MR's current head: compare `git rev-parse HEAD` with the MR `sha` (`glab mr view -F json`). If they differ and `git pull --ff-only` doesn't fix it, stop with `FAILED: worktree not at MR head`.
- Then pick the mode:
  - **Refresh**: the review file exists with a `reviewed_sha` frontmatter and `reviewed_sha` is not HEAD. The author pushed after the drafts were written.
  - **Re-review**: there's no review file, or only a notes-only file, and I (@viktomas) already have published threads on the MR.
  - **Initial**: neither of the above.
  - If the review file has a `reviewed_sha` equal to HEAD, the review is already done. Check that the drafts match the file (step 4) and go straight to the final message.

## 1. Context

Use the `review` skill for gathering context and for the criteria. Read every discussion on the MR (`glab mr note list`) and trace the requirements to the linked issue(s).
- **Re-review:** if a notes-only file exists, read it first: it has notes from earlier agents about what to check this time. Look at the diff since my last review. Check each of my threads (addressed, partly addressed, ignored) and don't re-raise points I already made. Draft follow-ups as replies on my threads. Go through each note too: drop it if it's resolved, turn it into a finding or reply if the MR should act on it now, and otherwise keep it and report it in the final message (e.g. "open an issue for X").
- **Refresh:** read the review file first. Run `git diff <reviewed_sha>..HEAD` and work from that change only:
  - a finding whose code the new commits didn't touch stays as it is. Don't re-verify it; its **Verified** note still holds.
  - a finding whose code was touched: re-check it, repeating the reproduction from its **Verified** note. If it's fixed, remove it from the file and say so in the final message.
  - new code no finding covers: review just that, and add findings.

## 2. Review and verify (initial and re-review; refresh only for touched or new code)

1. Review following the `review` skill. Tag findings P1/P2/P3.
2. Use the `subagent` skill to spawn a reviewer in a separate context that doesn't see your reasoning. Ask it to try to refute each P1/P2 finding and to look for simplifications you missed. Drop what it refutes (mention it in the Summary) and add the simplifications you agree with.
3. Reproduce P1/P2 where it's feasible locally: tests, a small script, or `tui-testing` for TUI behaviour. Don't start GDK; if only GDK would confirm it, say so in the comment. Record how you did it in **Verified**.
4. Mark each finding user-facing or maintenance in the comment.
5. **Leave the worktree clean.** Revert any tracked-file changes you made for a reproduction (`git checkout -- <files>`, delete stray untracked files). Describe them in **Verified** instead. `git status --porcelain` must be empty at the end, or the next scheduled update of this worktree fails.

## 3. Write the review file

Write or overwrite the review file: the frontmatter (`todo` from the arguments if given, otherwise keep the existing value; `reviewed_sha` = HEAD), the Summary, and one section per comment. Follow the review skill's comment guidelines.
- **Never write the review summary for GitLab.** The Summary section is for me and the next agent; I write the posted summary myself.
- Keep the `## Notes for the next review` section (carried over from a notes-only file, updated per step 1) and add new ones: e.g. simplifications or framework changes that are out of scope for this MR.

## 4. Sync the drafts to the file

1. `note draft list --json` to list the existing drafts.
2. **My edits win.** A draft whose text differs from the file's version of that comment was edited by me. Copy my text into the file, and keep my version from then on.
3. **Anchor everything to HEAD.** Delete every draft that's anchored to an older commit, or whose comment is no longer in the file (`note draft delete <id>`). Then create the missing ones from the file, anchored to HEAD: `note review` with a JSON array, or `note draft create`; see the `gitlab-mr-comments` skill, references/DRAFTS.md.
4. **Never publish.**

Don't use `note draft update` on diff drafts: it wipes the diff position, and the draft would publish as a general comment. To change a diff draft, delete it and create it again.

The result is exactly one draft per comment in the file, all on the current diff.

## Stop rules

- Don't ask me for permission between steps.
- If there's a real judgement call you can't resolve from the code, the issue or the discussion, stop with a Decide gate.
- If tooling fails twice (checkout, `note`, `glab`), stop with FAILED.

## Final message

- One line per comment: priority, file:line, the finding in one sentence, and whether it was reproduced, re-verified, or carried over unchanged (refresh).
- What you dropped or found fixed, and anything you couldn't verify.
- The very last line must be exactly one of:
  - `GATE: post - <n> draft comments on <short MR title>`
  - `GATE: post - no findings, ready to approve`
  - `GATE: decide - <the question, one line>`
  - `FAILED: <what broke>`

## When I come back

- **"publish" / "post":**
  1. If HEAD moved since `reviewed_sha` (`git fetch`, compare with the MR head), do a refresh first and show me what changed.
  2. Run `note draft publish --all`, then check that `note draft list --json` is empty. Don't go on if the publish failed.
  3. Mark the review-request TODO done: `glab api -X POST todos/<todo>/mark_as_done` using the file's `todo`. If it's empty, find my pending `review_requested` TODO for this MR via `glab api 'todos?state=pending&action=review_requested'`.
  4. If the file has a `## Notes for the next review` section, rewrite it as a notes-only file (see the review file section). Otherwise delete it (`rm "$(task state)"`).
  5. End with `DONE: published <n> comments`.
- Publish only when I explicitly say so.
