# Pre-commit hook + check.sh: extend to the global scope (proposal)

**Accepted and landed 2026-11-09** (owner decision 3; commit 72b0d83,
including the four prerequisites; global budget set at 60 lines, owner
delegated the number). This file is retained as the decision record.

Global pass, 2026-11-09 (finding: the live hook at `.agents/hooks/pre-commit`
scopes `^(AGENTS\.md|\.pi/|\.agents/)` — the global-scope paths
`agents/`, `pi/.pi/agent/`, `claude/` do NOT trigger it, so a bad
description or budget regression in the global skills can commit unchecked).
Rev 2: corrected after the 2026-11-09 opus review (the sequencing argument
was wrong — landing the description rewrites alone does NOT make the
extended validator green; four prerequisites are listed below).

## Recommendation: extend the existing hook + check, not a second check

One verification entry point (agent-scaffolding Phase 1, step 1). A
separate `.agents/check-global.sh` would duplicate the validator and give
"green" two meanings.

### 1. Hook regex (`.agents/hooks/pre-commit`)

```sh
changed=$(git diff --cached --name-only |
  grep -E '^(AGENTS\.md|\.pi/|\.agents/|agents/\.agents/skills/|pi/\.pi/agent/(AGENTS\.md$|skills/|prompts/)|claude/\.claude/)' || true)
```

Deliberately **excluded** (data/other-owned, must keep commits fast):
`pi/.pi/agent/sessions|duo-runs|fleet|kickoff-sessions|auth.json|models*`
and `pi/.pi/agent/extensions/` (TypeScript with its own tsconfig — a
sh/budget check adds nothing; revisit only if a lint story for extensions
appears). `AGENTS\.md$` is anchored so `AGENTS.md.orbit-backup` (ignored
anyway) can't match.

### 2. check.sh validator loops

Add the two global skill scopes to the existing loop:

```sh
for skill in .pi/skills/*/ agents/.agents/skills/*/ pi/.pi/agent/skills/*/; do
```

Notes:
- The `gitlab-mr-comments` submodule is inside `agents/.agents/skills/`;
  the validator reads it fine (verified — it passes at 50 words), but any
  fix must go upstream (gitlab.com/viktomas/gitlab-mr-comments), not this
  repo. If upstream drift makes that noisy, exclude the path and note it.
- Add a global AGENTS.md budget block, mirroring the repo-local one:

```sh
n=$(grep -c '' pi/.pi/agent/AGENTS.md)
[ "$n" -le 60 ] ||
  fail "global pi/.pi/agent/AGENTS.md is $n lines, over the 60-line budget"
```

(60 is a placeholder — owner picks; pairs with
`proposals/global-skills-budget.md`.)

### 3. Prerequisites — without these the extended validator goes live red

Measured today: 10 of 21 model-invocable global descriptions are outside
the 30–55 band (5 over, 5 under), gdk lacks trigger style, and even after
all 8 rewrites land, the extended check.sh would still fail on 6 skills.
Fix these in check.sh as part of the same change:

1. **Keyword-trigger allowlist** (downloads, git-worktree, wait-for are
   deliberately under 30 words — effective keyword triggers, no standing
   cost): an explicit allowlist variable checked before the word floor.
2. **Skip manual-only skills** (`disable-model-invocation: true`, e.g.
   agent-scaffolding): their descriptions are never loaded, so the
   trigger-style rule doesn't apply to them.
3. **Strip `#anchor` fragments from link targets** in the link-existence
   check (`references/gql.md#troubleshooting` currently fails although the
   file exists). This is a straight bug in today's repo-local check too —
   fixed separately, see AUDIT.md.
4. **Parse frontmatter with a real YAML parser** (or minimally: fail on
   `: ` — colon+space — inside an unquoted description). An unquoted
   plain scalar containing `: ` is invalid YAML; pi then refuses to load
   the skill and headless sessions die before starting. This bit during
   this pass (see journal 2026-11-09-skill-frontmatter-colon-space); a
   validator without it would have approved the broken descriptions —
   they were inside the word budget and trigger-style.

Also covers finding 3's drift risk going forward: any new/edited global
skill description is budget-checked at commit time, so the
"recently curated, review later" loop closes mechanically instead of by
remembering.

### 4. Sequencing (the gate)

1. Land the description rewrites (`global-skills-budget.md`) + smoke runs.
2. Then extend hook regex + check.sh loops + global budget + the three
   prerequisites above in one commit — validator must be green on main
   the moment it lands (Phase 1: add rules only when violations are fixed
   or allowlisted).
3. Hook re-verified the same three ways as 2026-11-09: data-only staging
   fast-path (~25 ms), scaffolding staging runs check, a real violation
   blocks.

Claude-side gap (recorded, no mechanism possible here): `~/.claude/CLAUDE.md`
carries the orbit-managed setup block (~400 tok, always-loaded in claude
sessions) and lives outside this repo — orbit owns it; if it re-adds
content after `glab orbit setup`, prune there, same as the pi AGENTS.md
note. Same for `~/.gitlab/duo/AGENTS.md`, which still carries the old
gitlab-api description (owner action, outside the repo).

Revert: restore the two files (`git checkout -- .agents/hooks/pre-commit
.agents/check.sh`) — the hook is versioned and already live via
`core.hooksPath`.
