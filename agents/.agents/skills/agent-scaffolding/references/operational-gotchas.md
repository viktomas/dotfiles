# Operational gotchas

Technical details that bit when the guidelines were first applied (2026-11-05,
pi harness, a non-code personal knowledge repo, Phases 0–3). The principles
live in [guidelines.md](guidelines.md); this file holds the implementation
detail behind them. Harness specifics (pi paths, env vars) are examples; check
the equivalent in your harness.

## Measuring always-loaded context

- The rendered skill-description block is always-loaded and can be the largest
  item: ~11k chars (~2.75k tokens) for ~28 skills, against ~1k tokens for each
  AGENTS.md. Measure it, don't estimate it from the files: descriptions from
  every scope (global and repo) are merged, and disabled skills are left out.
- Measure from a live session's log. In pi, the first `message` record with
  `role: system` in the session jsonl carries `message.sections` (`skills`,
  `project_context`, `tools`, …); `chars / 4` is a good enough token estimate.
- Harness-owned sections (preamble, tools, docs) aren't curatable; report them
  separately so the curatable total isn't inflated.

## Isolating the agent under test

The rule: sandbox the agent under test. Close stdin, sanitize the environment,
never let it write durable state, and use fakes for anything with side effects.
A first runner hit all four of these:

- **stdin.** Headless `pi -p` reads stdin when it isn't a tty. Inside a
  `while read` loop over cases it swallowed the remaining rows, so only the
  first case ran. Run every case with `</dev/null`.
- **Inherited session identity.** Eval sessions inherited `TASK_ID` from the
  session that launched them, behaved as task sessions, and wrote notes into
  the real task's state file. Strip every session-identifying or
  privilege-granting variable (`env -u TASK_ID -u PI_GARDENER …`); list the env
  vars your extensions read and decide for each one.
- **Session-log discovery.** To see which skills a case loaded, find the new
  session log and scan its assistant tool calls for `…/skills/<name>/SKILL.md`.
  pi keeps logs in `~/.pi/agent/sessions/<slug>/`, where slug is `--` + the cwd
  with the leading `/` stripped and `/` → `-` + `--` (`/a/b` → `--a-b--`).
  Snapshot the directory listing before each case and take the new file after;
  a wrong slug makes every case fail with "no session found".
- **Parsing case tables.** `IFS=$'\t' read` treats tab as whitespace, so
  consecutive tabs collapse and an empty cell (e.g. no "must not read") shifts
  the remaining columns. Use a non-whitespace delimiter such as `\037` (0x1f).
- **Durable writes.** After a run, `git status` should show nothing new. Prefer
  a throwaway worktree for task and replay cases, and put fake tools first on
  `PATH` for anything that talks to live services.

## Eval corpus leakage

- In-repo eval files are in the agent's reach: one eval agent grepped
  `evals/triggers/*.md`, found its own prompt and said so. For trigger checks
  that is tolerable; for task and replay cases it invalidates the result.
- Keep trigger prompts terse and natural, and run replay tasks from a checkout
  of the base commit or tag (taken before the eval files existed), not from the
  working tree.

## Cost calibration

Measured on a fast default model, 2026-11-05:

| Case type | Cost |
|---|---|
| Simple trigger case | ~$0.02–0.08 |
| Open-ended trigger case (one ran 55 turns) | $0.15–1.10 |
| Full 20-case trigger suite | ~$1–1.5 |
| First suite including runner debugging | ~$3.20 total |

- The trigger signal is decided in the first 2–3 turns; everything after is
  the task itself. Cap turns (or time out) for trigger cases, or run them on
  the cheap model.
- While iterating on one description, run that skill's case file only.

## Skill validator

Details for the Phase 3 "validate in CI" step:

- **Name.** Frontmatter `name` must match the directory name.
- **Description.** Check model-invocable skills only (skip
  `disable-model-invocation: true`): 30–55 words and trigger style (for
  example, require "Use when"). Put the remediation in the error message.
- **Reference paths.**
  - Glob references (`drafts/manager-1on1-*.md`) can't be checked literally;
    check that their directory exists.
  - Skip placeholder templates such as `archive/done/YYYY-MM.md` or
    `<project>/notes.md`; they aren't paths.
  - Expand `~`-prefixed paths before testing them.
  - Strip trailing punctuation picked up from prose (`.`, `,`, `)`).
- **Body size.** Warn before failing (for example, warn at 6,000 chars and
  fail at 7,000) so a growing skill gets split before it blocks a commit.

## Hooks in a shared repo

When always-on automation also commits (a scheduled refresh, other agents),
scope the pre-commit hook to scaffolding paths
(`git diff --cached --name-only | grep -qE '^(AGENTS\.md|\.pi/|scripts/|evals/)'`)
so data commits stay fast and are never blocked by scaffolding checks. Unset
`GIT_INDEX_FILE`, `GIT_DIR` and `GIT_WORK_TREE` before running `check` from the
hook if the check itself calls git.
