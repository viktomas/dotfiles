---
description: Land my MR - apply feedback, verify, push, get the pipeline green, draft replies, then merge
argument-hint: "<what to apply, e.g. '1 and 3' or 'the reviewer feedback'>"
---
Land my MR on the current branch. Apply: ${@:-the unresolved reviewer feedback}

Run every step below yourself, without stopping to ask me. Stop only at the gates named here.

1. **Context.** Find the MR for the current branch (`glab mr view`) and read its unresolved discussions (`glab mr note list --state unresolved`).
2. **Apply the literal ask.** Implement exactly what's requested above (or exactly what each reviewer asked for) and nothing more.
   - Stop with `GATE: decide` if applying it would:
     - change behaviour beyond the literal ask;
     - loosen, skip or delete a test;
     - leave two reasonable ways to do it.

     Never pick an edge case for me.
   - If a reviewer's ask is unclear, draft a clarifying reply (step 6) instead of guessing.
3. **Verify in a separate context.** Use the `subagent` skill to spawn a reviewer that reviews your diff adversarially, following the `review` skill criteria. Fix the real issues it finds within the scope of the ask. Anything outside that scope goes into the final message; don't fix it.
4. **Local checks.** Run the tests and lint relevant to the change.
5. **Commit, push, pipeline.**
   - Use conventional commits and push.
   - Then follow the rules in `~/.pi/agent/prompts/pipeline.md`: read it, use `wait-for`, never force-push, and make at most two fix attempts for a real failure.
   - Rerun a job that failed for flaky or infra reasons up to 3 times.
   - If the branch needs a rebase (conflicts), stop with `GATE: decide - rebase needed (force push)`.
   - A test failure outside the change's scope, or a fix that would need a behaviour or test change, is also a Decide.
6. **Draft replies** to every thread you addressed, as drafts (`note draft create --reply <id>`, see the `gitlab-mr-comments` skill, references/DRAFTS.md). Each reply starts with `:robot: AI-generated`, says what changed, and links the commit. Never publish them yourself.

**Final message**
- What you changed per thread, the commits, and the pipeline status.
- Anything the verifier flagged that you left out of scope.
- The very last line must be exactly one of:
  - `GATE: reply - <n> draft replies, pipeline <green|status>`
  - `GATE: decide - <the question, one line>`
  - `FAILED: <what broke after the strike limit>`

**When I come back:**
- **"publish" / "post":** run `note draft publish`. Then:
  - if the MR is approved and the pipeline is green, end with `GATE: merge - approved and green, add to merge train?`;
  - otherwise end with `DONE: replies posted, waiting on <reviewer>`.
- **"merge":**
  - add the MR to the merge train (or set auto-merge when merge trains are off);
  - watch it with `wait-for`;
  - rerun train jobs that failed for flaky or infra reasons up to 3 times;
  - a real failure is `FAILED: <job>`.
  - Once it's merged, run `task done` (it closes this session).
