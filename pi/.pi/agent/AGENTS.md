prefer `fd` and `rg` over `find` and `grep`
`rg` uses `-t` for file type

My GitLab username is @viktomas.

## Shell

The user uses `fish` as their shell. When helping with anything related to the user's environment (aliases, shell config, environment variables, PATH, etc.), use `fish` syntax and test commands with `fish -c '<command>'`. Note that some config (e.g. abbreviations, interactive key bindings) is only loaded in interactive mode — use `fish -ic '<command>'` when testing those.

## **CRITICAL** Planning Rules **CRITICAL**

You are working with a plan if:
- You are **explicitly asked** to work with `plan.md`
- The user says `@plan.md go`, `@plan.md step N go`, or similar
- A `/next` command was used (it references plan.md in its prompt)

When working with a plan, `plan.md` is your only file for documenting progress. Unless asked to create other documentation files, use the `plan.md` exclusively.

**MANDATORY**: After completing ANY task from the plan (coding, reverting, creating files, etc.), you MUST immediately update `plan.md` BEFORE responding to the user. This is NOT optional.

When you complete a task:
1. Remove the completed step entirely from the plan — no trace of it should remain
2. Update "Current State" to reflect what's now done
3. Update "Problem" to remove solved issues
4. Remove any "before/after" language - document only the current reality
5. Renumber remaining steps if needed

When updating the `plan` make sure there are no:
- finished steps in any form — no "DONE" markers, no checked todos, no completed step headings
- before and after sections - only current state is documented
- checked todos or description of performed migration steps - only the remaining migration steps are explained
- selling of the solution (no "benefits", "improvements", "why is this the best")

If you complete work but don't update the plan automatically, you have FAILED your task.

## Verification After Implementation

After completing implementation work, verify it compiles and passes tests. Don't ask the user to paste errors — run the commands yourself and read the output.

- `./scripts/dev/verify.sh` — compile + test + lint changed files (if available)
- `./scripts/dev/test-file.sh <file>` — run a single test file (if available)
- `./scripts/dev/fix-changed.sh` — lint/format only changed files (if available)

 ## **CRITICAL** Tool Usage Rules **CRITICAL**
- NEVER use sed/cat to read a file or a range of a file. Always use the read tool (use offset + limit for ranged reads).
- You MUST read every file you modify in full before editing.


## Forbidden Git Operations
These commands can destroy your's other agents' work
- `git reset --hard` - destroys uncommitted changes
- `git checkout .` - destroys uncommitted changes
- `git clean -fd` - deletes untracked files
- `git stash` - stashes ALL changes including other agents' work
- `git add -A` / `git add .` - stages other agents' uncommitted work
- `git commit --no-verify` - bypasses required checks and is never allowed
- `git commit` - don't commit unless asked


You can only use them on direct user request.

## Git Interactive Commands

Commands like `git rebase --continue`, `git merge --continue`, and `git commit` open an editor and hang when run non-interactively. Always prefix with `GIT_EDITOR=true` to auto-accept the default message:

```bash
GIT_EDITOR=true git rebase --continue
GIT_EDITOR=true git merge --continue
```

