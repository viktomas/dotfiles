prefer `fd` and `rg` over `find` and `grep`

## **CRITICAL** Planning Rules **CRITICAL**

You are working with a plan if you are **explicitly asked** to work with `plan.md`. In such case the `plan.md` is your only file for documenting your progress. Unless asked to create other documentation files, use the `plan.md` exclusively.

**MANDATORY**: After completing ANY task from the plan (coding, reverting, creating files, etc.), you MUST immediately update `plan.md` BEFORE responding to the user. This is NOT optional.

When you complete a task:
1. Remove completed TODO sections/steps from the plan
2. Update "Current State" to reflect what's now done
3. Update "Problem" to remove solved issues
4. Remove any "before/after" language - document only the current reality
5. Renumber remaining steps if needed

When updating the `plan` make sure there are no:
- before and after sections - only current state is documented
- checked todos or description of performed migration steps - only the remaining migration steps are explained
- selling of the solution (no "benefits", "improvements", "why is this the best")

If you complete work but don't update the plan automatically, you have FAILED your task.

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


You can only use them on direct user request.
