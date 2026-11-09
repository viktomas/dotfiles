# Operational gotchas

Technical details that bit when the guidelines were applied across three
repos (2026-11-05→09: a dotfiles/config repo, a non-code knowledge repo, a Go
web app; Phases 0–5). The principles
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
  Derive it from the realpath of the cwd — on macOS `/tmp` is `/private/tmp`,
  and a naive slug makes every case report "no session found".
  Snapshot the directory listing before each case and take the new file after.
- **Parsing case tables.** `IFS=$'\t' read` treats tab as whitespace, so
  consecutive tabs collapse and an empty cell (e.g. no "must not read") shifts
  the remaining columns. Use a non-whitespace delimiter such as `\037` (0x1f).
- **Durable writes.** After a run, `git status` should show nothing new. Never
  run a case in the real tree — an early case edited a source file before
  anyone noticed. Make isolation structural: the runner copies the working
  tree to a throwaway directory (minus `.git` and the eval files) for trigger
  cases, uses a pruned clone for replay cases, and refuses to start when the
  cwd is the real repo. Put fake tools first on `PATH` for anything that talks
  to live services, and rewrite or shim absolute home paths in skill bodies —
  they break a copy-based sandbox.
- **Between cases.** Kill anything a case left running — fixture servers,
  agent-spawned browsers — or it trips the next case. Don't edit a runner
  script while it runs; sh reads incrementally and the edit can crash its tail.
- **Counting loads.** A skill opened with `cat` in bash is a load too: scan
  for every way a body can be read, not just the `read` tool. A skill read
  and then rejected still counts as loaded (known limitation).
- **Provider outages.** Discard runs that end in empty error turns and rerun
  them; counting them as fails poisons the metric.

## Eval corpus leakage

- In-repo eval files are in the agent's reach: one eval agent grepped
  `evals/triggers/*.md`, found its own prompt and said so. For trigger checks
  that is tolerable; for task and replay cases it invalidates the result.
- Keep trigger prompts terse, natural, and *true*. A false premise — naming
  a file that doesn't exist, or pointing at the wrong file — lets the agent
  treat a trigger case as a lookup and skip the skill; reword the case, not
  the description.
- Agents read git history. Run replay tasks from a clone **pruned to the
  base**: delete all refs and the origin remote, expire reflogs
  (`git reflog expire --expire=now --all`), then gc — otherwise the agent can
  find the landed solution in `git log` (one did, within 8 turns). History
  below the base survives and is fine.
- Overlay the scaffolding under test — AGENTS.md, validators, skills, never
  the audit, plan or eval files — from the working tree onto the base, and
  check every referenced path exists at every base; a plain base checkout
  measures the old scaffolding.

## Cost calibration

Measured on a fast default model, 2026-11-05:

| Case type | Cost |
|---|---|
| Simple trigger case | ~$0.02–0.08 |
| Open-ended trigger case (one ran 55 turns) | $0.15–1.10 |
| Full 20-case trigger suite | ~$1–1.5 |
| Replay gate subset (4 tasks × 3 runs) | ~$11 |
| Full replay suite (7 tasks × 3 runs) | ~$70 |
| First suite including runner debugging | ~$3.20 total |

- The trigger signal is decided in the first 2–3 turns; everything after is
  the task itself. Cap turns (or time out) for trigger cases, or run them on
  the cheap model.
- While iterating on one description, run that skill's case file only.
- A replay suite can dwarf a trigger suite. Split the tasks: a cheap **gate**
  set runs on every scaffolding change, the full set is measured quarterly.
  Enforce a cumulative spend cap in the runner that stops the run once crossed
  — per-task cost varies more than 2×, so the cap, not the estimate, bounds
  spend — and order the gate set cheapest-first so a truncation still buys
  signal. A cap below the gate set's own full cost is a legitimate owner
  choice.

## Replay acceptance

- **Scope the acceptance run.** Old base commits carry time-bomb tests
  (absolute dates, red for anyone later). Run the target commit's own test
  packages, not the whole suite.
- **Verify the green property per task** before trusting a red: the target
  commit plus the scaffold overlay must pass the acceptance; verify the red
  property once on a deliberately broken pilot.
- **Prefer public-behavior acceptance.** Tests that pin internal symbol names
  or signatures fail agents whose implementation is equivalent but shaped
  differently — deterministic 0/3, cost without pass-rate signal. Pick seed
  commits whose tests exercise handler or e2e behavior.

## Skill validator

Details for the Phase 3 "validate in CI" step:

- **Name.** Frontmatter `name` must match the directory name.
- **Description.** Check model-invocable skills only (skip
  `disable-model-invocation: true`): 30–55 words and trigger style (for
  example, require "Use when"). Put the remediation in the error message.
- **YAML validity.** Parse the frontmatter with a real YAML parser rather than
  pattern-matching it. The bug class that bit: `: ` (colon+space) inside an
  unquoted plain-scalar description is invalid YAML, the harness then refuses
  to load the skill, and headless sessions die before creating a log —
  surfacing at session start, not commit time. Style rule: ` - ` instead of
  colons.
- **Keyword-trigger allowlist.** A pure keyword-trigger description under the
  30-word floor is acceptable while a passing trigger eval is on record:
  under-length costs nothing, over-length is paid every session.
- **Reference paths.**
  - Glob references (`drafts/manager-1on1-*.md`) can't be checked literally;
    check that their directory exists.
  - Skip placeholder templates such as `archive/done/YYYY-MM.md` or
    `<project>/notes.md`; they aren't paths.
  - Expand `~`-prefixed paths before testing them.
  - Strip trailing punctuation picked up from prose (`.`, `,`, `)`).
  - Skip fenced code blocks when scanning for links, and strip `#anchor`
    fragments from targets — the file is what must exist.
  - `wc -w` counts a standalone em dash as a word; trim punctuation before
    counting.
  - Skip only the *description* check for manual-only skills; body-size and
    reference checks still apply.
- **Body size.** Warn before failing (for example, warn at 6,000 chars and
  fail at 7,000) so a growing skill gets split before it blocks a commit.

## Hooks in a shared repo

When always-on automation also commits (a scheduled refresh, other agents),
scope the pre-commit hook to scaffolding paths
(`git diff --cached --name-only | grep -qE '^(AGENTS\.md|\.pi/|scripts/|evals/)'`)
so data commits stay fast and are never blocked by scaffolding checks. Unset
`GIT_INDEX_FILE`, `GIT_DIR` and `GIT_WORK_TREE` before running `check` from the
hook if the check itself calls git.

## Guard design

- Confirm-to-proceed beats a hard block when the owner often asks for the
  guarded action on purpose; headless runs (no UI) fail closed with a
  remediation message instead of wedging.
- Log every confirm — allowed, declined, or fail-closed — into the session
  transcript (never sent to the LLM). That log is how false positives get
  found: by grepping sessions, not by the owner remembering to complain.
- Resolve absolute tool paths against the session cwd. A guard matching only
  repo-relative patterns never sees an absolute-path edit to a guarded file.
- Match on effect, not mention, in bash commands: exempt read-only git
  stages, count redirects only when the *target* is guarded, blank quoted
  text and heredocs before matching, and require a write verb in the same
  pipeline unit as the guarded path.
- Negative-test every guard and every check. A green `check` that silently
  skips its lints (a make prerequisite with no recipe) is worse than red;
  extend hook path patterns and the validator together, or changes ship
  through the scope gap between them.
- Repo-local extensions load from the session cwd: an old worktree runs the
  old guard.
