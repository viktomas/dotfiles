---
name: review
description: Use when asked to review a change in this session — a pasted diff, uncommitted or local changes, a commit, or a GitLab merge request by IID, URL or current branch — and optionally post the findings as MR comments. Not for launching a dedicated review-task session (`gitlab-mr-review`) or comment/note mechanics alone (`gitlab-mr-comments`).
---

# Review

One rubric for every change. Get the diff and its context, review it, present findings. MR reviews may end with posting comments, but only after I confirm.

## 1. Get the change

- **Pasted diff**: review it as given.
- **Commit**: `git show <sha>`.
- **Local changes**: if the working directory has changes, ask whether I want only the uncommitted changes or the full diff with main. If it's clean (or I want the full diff), find the merge base with main and review from there.
- **GitLab MR** (IID, URL or the current branch's MR): run the context script from the MR's local repo (find it with the `projects` skill; with a URL, pass its IID):

  ```bash
  ~/.agents/skills/review/scripts/get-mr-context.sh [--mr <IID>] [--diff-source local|remote]
  ```

  It prints `=== TOOLS ===`, `=== BRANCH_STATE ===`, `=== MR_METADATA ===`, `=== REVIEW_INSTRUCTIONS ===`, `=== DIFFS ===`. Follow its `hint:` lines (e.g. dirty branch → ask me local vs remote, re-run with `--diff-source`). Treat `REVIEW_INSTRUCTIONS` as repo rules for this review.
  **Re-review** (author answered an earlier round): also run `glab mr note list --state unresolved`; for each of my earlier threads decide addressed / partly / ignored before adding new findings, and don't re-raise points I already made.

## 2. Gather context

- MR description plus every referenced issue and MR (`glab`, or the `gitlab-api` skill). Get as much context as you can on *why* the change exists.
- Relevant `architecture.md` files next to the changed paths (`fd -i architecture.md`).
- If the MR pipeline is green, don't run tests or compilation.

## 3. Issue criteria

Report issues that:

1. Meaningfully impact correctness, performance, security, or maintainability (logic/edge cases, races, injection/auth/secrets, N+1, unbounded work, missing error handling).
2. Are discrete and actionable — one issue per finding.
3. Don't demand rigor inconsistent with the rest of the codebase.
4. Were introduced by the change being reviewed (not pre-existing bugs).
5. Don't rely on unstated assumptions about the codebase or author's intent, and are clearly not intentional.
6. IMPORTANT: Have provable impact — don't speculate that a change may break another part; identify the parts provably affected.
7. Touch untrusted user input (see below).
8. Code comments that explain WHAT the code does. I only want comments that explain WHY.
9. Unnecessary tests — duplicates or tests of something trivial.

Don't flag style nits unless they obscure meaning or break documented standards.

### Untrusted user input

For every new input (CLI flag, input field, URL parameter, config file), trace where it's used and whether it can affect execution. Assume someone will try to exploit it: what's the blast radius, can it run arbitrary code?

- Input from the user (CLI args, global settings in the user's home): running arbitrary code is probably OK.
- Input from a project (untrusted project settings, any repo from the internet): must not trigger arbitrary code without user approval.

### Complexity

Look out for (accidental) complexity — the change may only contribute to it.

- Could part of a complex algorithm move into data structures?
- Flag code that seems too complex for the goal/mental model of the logic.
- Suggest a partial re-architecture if it clearly simplifies the code.

### Review priorities

1. Call out newly added dependencies and explain why they're needed.
2. Prefer simple, direct solutions over wrappers or abstractions without clear value.
3. Favor fail-fast behavior; avoid logging-and-continue patterns that hide errors.
4. Prefer predictable production behavior; crashing beats silent degradation.
5. Check errors against codes or stable identifiers, never error messages.

### Priority levels

Tag each finding in its title:
- **[P1]** Urgent — fix before merging.
- **[P2]** Normal — fix eventually.
- **[P3]** Low — nice to have.

## 4. Output

1. **Verdict**: looks good / needs attention. With no qualifying findings, say explicitly that the code looks good.
2. High-level explanation of why the change is needed and how it achieves the goal.
3. Five key snippets that best tell the story of the change, explaining how the key parts work.
4. The places with the highest complexity.
5. Findings, each as:

   ```
   **[P1] Title of finding**
   File: `path/to/file.ext`, lines 42–48
   Why it's a problem, when it happens, what it affects.
   ```

### Comment guidelines

1. Be clear about why the issue is a problem.
2. Communicate severity appropriately — don't exaggerate.
3. Be brief — at most 1 paragraph.
4. Keep code snippets under 3 lines, in inline code or code blocks.
5. Use \`\`\`suggestion blocks ONLY for concrete replacement code (minimal lines, no commentary inside). Preserve the exact leading whitespace of the replaced lines.
6. State the scenarios/environments where the issue arises. IMPORTANT: focus on the impact on the user or app stability.
7. Matter-of-fact tone — helpful, not accusatory.
8. Write for quick comprehension without close reading.
9. No flattery or filler ("Great job...").

## 5. Posting (MR reviews only)

End an MR review by asking whether to post the findings. **Never post without my confirmation.** To post immediately, use `scripts/post-comment.sh` — see [references/posting.md](references/posting.md). For draft comments I publish myself, use the `gitlab-mr-comments` skill (`note`).

---

After the review, expect me to ask you to verify the user impact of the P1 and P2 findings by running the code and reproducing them — don't do that in the initial review.
