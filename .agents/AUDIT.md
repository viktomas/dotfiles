# Agent-scaffolding audit — dotfiles (repo-local scope)

Running log for the agent-scaffolding effort (skill:
`~/.agents/skills/agent-scaffolding`) **scoped to this repo's own
scaffolding** — `AGENTS.md`, `.pi/skills/*`, repo mechanisms. The global
agent scope (`agents/` = `~/.agents`, `pi/.pi/agent/` = global pi skills and
extensions, `claude/`, and `pi/.pi/agent/purge/`) was excluded from the
repo-local phases and got its own pass on 2026-11-09 — outcomes in the
**Global-scope pass** section at the bottom. The findings recorded below
as data were verified there.

**`.agents/` here is repo state, not a stow package** — never add it to
`install.sh` (the check script asserts this). `~/.agents` is a symlink to
`agents/.agents`, so any audit state under `agents/` would be global.

## Phase 0 — baseline audit (2026-11-06)

### Always-loaded context (measured from a live session log)

Session `~/.pi/agent/sessions/--Users-tomas-.dotfiles--/
2026-11-01T11-17-16-*.jsonl` (newest available; skills set may have drifted
slightly since), first system message:

| Section | Chars | ~Tokens | Curatable? |
|---|---|---|---|
| project_context | 5,005 | 1,251 | yes |
| skills (descriptions) | 9,456 | 2,364 | yes |
| preamble + tools + rules + docs + cwd | 2,731 | 681 | no (harness) |

project_context = global `~/.pi/agent/AGENTS.md` (2,381 chars, ~595 tok) +
this repo's `AGENTS.md` (750 chars, ~187 tok) + wrapper.

**dotfiles-controllable always-loaded cost: ~310 tok/session** (AGENTS.md
187 + nvim-theme description ~120). The global skills block (~2,364 tok) is
the big item but is out of scope here.

### Skills inventory (repo scope)

- `.pi/skills/nvim-theme` — model-invocable, description ~70 words (over the
  30–55 trigger budget, summarizes contents), body 9,751 chars, 1 `scripts/`
  dir (tiers.sh, capture.sh, decode.py, compare.py), no references, no
  evals. No same-name skill in any other scope (global has none named
  nvim-theme).
- No other repo-scope skills. `.pi/` has no hooks, no settings.

### Mechanisms inventory

- No CI (no Forgejo Actions / GitHub workflows), no git hooks
  (`core.hooksPath` unset, no active hooks), no lint, no tests.
- Nearest-equivalent gap noted per the guidelines: a repo-local check
  script + optional pre-commit hook scoped to scaffolding paths.

### AGENTS.md classification (16 lines)

| Lines | Class | Verdict |
|---|---|---|
| 1 `git wta` branch naming | K | keep (repo-specific convention; overlaps the global git-worktree skill but carries this repo's `tv/YYYY-MM/<name>` naming) |
| 3–6 dev-env pointer to "the `dotfiles` skill (`pi/.pi/agent/skills/dotfiles/SKILL.md`)" | **S** | **stale** — that skill was purged (dotfiles commit `2b39167`); it now lives only in `pi/.pi/agent/purge/skills/dotfiles/`. Point at `README.md` (which has the per-tool doc table) instead |
| 8–13 kanata/karabiner | K | keep (pointer + why Karabiner is kept) |
| 15–16 HRM/symbol quick ref | K (borderline I) | keep — 2 lines, high-recurrence questions, saves loading kanata/README.md; flagged for the next gardener pass |

### Baseline metrics

- AGENTS.md: 16 lines / 750 chars (~187 tok).
- Repo-controllable always-loaded: ~310 tok/session.
- CI pass rate / review rounds: not measurable — no CI, direct commits.

### Eval seed (recorded; runner deferred to Phase 5)

Typical repo-local work (global-scaffolding commits excluded):

| Task statement | Base |
|---|---|
| stop painting instantiation sites as declarations (theme) | `2d3aeeb^` |
| `gt` on `$task-id` switches to that task's zellij session (nvim) | `582284d^` |
| single-mod fzf bindings for HRM (fish) | `962028f^` |
| document dropped-modifier recovery (kanata docs) | `da250af^` |

Acceptance gap: config repo, mostly manual verification; the nvim-theme
scripts are the only automatable acceptance (theme tasks), noted as a gap.

### Global-scope findings (recorded only; act in the global pass, later)

1. `pi/.pi/agent/purge/` holds ~16 purged skills, several same-named with
   live global ones (projects, gitlab-api, gdk, wait-for, git-worktree,
   dotfiles). A purged skill still shadows same-name skills in broader
   scopes — the purge map needs a dedicated review. The stale AGENTS.md
   pointer fixed in this pass is the first casualty of that pattern; grep
   for other references to purge paths during the global pass.
2. `claude/.claude/skills/gitlab-api` duplicates `agents/.agents/skills/gitlab-api`
   across harness scopes.
3. The global skills description block (~2,364 tok) is the largest curatable
   always-loaded item in every session, in every repo — recently curated
   (2026-11-05 pass, commit `6f4755b`), review later.
4. The workspace-parent `ai/AGENTS.md` (~1,055 tok) rides along in every
   lifeos session — third repo, record only.
5. Skill moves and purges leave dangling doc references: three found in
   this repo alone (AGENTS.md's `dotfiles` pointer, README.md's
   `bin/edit-crontab.sh`, nvim/README's global-scope nvim-theme path) —
   each a file moved without its references. The global pass should grep
   repo docs and `~/.agents` content for every old path it touches.

### Gate

Phase 0 gate (human reviews classification): **pending**.

## Outcomes log

- **2026-11-06 Phase 2 (proposed, uncommitted):** fixed the S line — the
  stale `dotfiles` skill pointer (purged in `2b39167`) replaced with a
  pointer to `README.md`'s per-tool doc table; added a 5-line Scaffolding
  section (journal, propose-don't-merge, `.agents/` is not a stow package).
  Principles 3, 7. Net: 16 → 22 lines, ~+130 tok offset against a
  dangling reference that would have sent agents to a dead path. Revert:
  `git checkout -- AGENTS.md`.
- **2026-11-06 Phase 1/2/3 gate mechanism (proposed, uncommitted):**
  `.agents/check.sh` — AGENTS.md line budget (28, placeholder — owner
  picks), skill frontmatter validator (name/dir match, 30–55-word trigger
  description, relative link targets exist), and a stow guard (asserts
  `install.sh` never stows `.agents`). No CI in this repo, so the nearest
  equivalent is running it before committing scaffolding changes; wiring a
  pre-commit hook is left as an owner decision (hooks = gardener PR +
  human). Principles 2, 10. Revert: delete the file.
- **2026-11-06 Phase 3 (proposed, uncommitted):** `nvim-theme` —
  description rewritten 70 → 50 words, trigger-style (when-to-load, not
  contents); the `compare.py` deep-dive (~3.3k chars of scenario detail)
  moved to `references/compare.md` with a short pointer left in the body
  (progressive disclosure: it costs nothing until an options question
  happens). Eval cases + isolated runner added. First trigger run (3
  read-only cases, from a throwaway copy of the repo): **3/3** —
  should-wrong-colour and should-light-variant both load the skill (via
  `cat` in bash, which the runner counts), shouldnot-ghostty-colours
  correctly loads nothing. The write-y cases (tier-change, compare-options,
  add-plugin, fish-prompt) are deferred to the phase-5 sandboxed runner:
  they instruct edits, and the skill's scripts use absolute `~/.dotfiles`
  paths, so a copy doesn't contain them. Principles 4, 6. Revert:
  `git checkout -- .pi/skills/nvim-theme/`.
- **2026-11-06 Phase 4 setup (proposed, uncommitted):** `.agents/journal/`
  with README format; working-agreement lines in AGENTS.md.
- **2026-11-06 Phase 5, sandboxed runner (proposed, uncommitted):**
  `.pi/skills/nvim-theme/evals/sandbox.sh` — throwaway /tmp copy of the
  repo (minus 1.4G of pi session data), rewrites the skill's absolute
  `~/.dotfiles` references (SKILL.md, references/, nvim/THEME.md) to the
  copy, PATH-shims nvim so the copy's config dir is first on rtp
  (verified: `user.theme` resolves to the copy; plugins/LSP stay real —
  the config uses vim.pack, which doesn't reorder rtp), runs `run.sh`
  from inside the copy, then reports the eval agent's writes as a
  git-status delta, checks the real vim.pack dir for drift, and deletes
  the sandbox. `run.sh`: env isolation extended per the gotchas (now also
  strips TASK_DIR, TASK_CATEGORIES, PI_SESSION_FILE/ID/TAG,
  PI_MODEL/PROVIDER/REASONING) and takes case-id args for bounded
  single-case iteration. Fixed en route: a failing suite no longer
  aborts sandbox.sh before its write-report/cleanup steps.
  **Full 7-case suite ×3 + 1 debug + 3 single-case + 1 post-change run
  (~29 case-sessions, ~$2-3):**

  | case | load rate | failures classified |
  |---|---|---|
  | should-light-variant | 4/4 | — |
  | shouldnot-fish-prompt | 4/4 clean | — |
  | shouldnot-ghostty-colours | 4/4 clean | — |
  | should-compare-options | 3/4 | 1× nothing-loaded, answer correct — the agent reinvented compare.py's job by hand in 24 turns (cost evidence *for* the skill; per guidelines, recorded not tuned) |
  | should-tier-change | 3/5 | 2× nothing-loaded, answer correct from THEME.md — the docs carry it for pure "what is this tier" questions; recorded not tuned |
  | should-wrong-colour | 1/3 → **3/4 after tuning** | real misses: generic `:Inspect` answers that never produce the actual painted colour |
  | shouldnot-add-plugin | 3/4 | 1× wrong-skill load, but read-to-reject after the agent found the eval corpus (it announced "this is a 'shouldnot' trigger case") — leakage-influenced, not a description problem; runner counts read-to-reject as a load (known limitation) |

  Suite pass rates: 6/7, 4/7, 5/7 (pre-change), 6/7 (post-change) —
  single runs are noise (±1.5); gating comparisons need ≥3 runs. The
  wrong-colour trigger clause was tuned ("…when a token has the wrong
  colour and the real on-screen value is needed…"; description now 55
  words, at budget). Writes containment verified in anger: the plugin
  case edited init.lua, the lock file and added
  `lua/plugins/whichkey.lua` — all inside the sandbox; no drift in the
  real vim.pack dir; the real repo untouched. Skill-loaded runs cost 7-21
  turns (the capture loop's 14 s LSP waits ×2 variants are deliberate);
  the manual reimplementation miss cost 24. Principles 1, 6. Revert:
  delete sandbox.sh, restore run.sh and the description.
- **2026-11-06 stale-pointer sweep, repo-local (proposed, uncommitted):**
  swept README.md, AGENTS.md, per-package READMEs, bin/, install.sh for
  dead paths. Two found and fixed, both the same pattern (files moved
  without their references):
  - README.md's crontab line pointed at `bin/edit-crontab.sh`, renamed
    `bin/,edit-crontab` in `ef80870`.
  - nvim/README.md pointed at the nvim-theme skill under
    `pi/.pi/agent/skills/` (global) — the skill moved to project scope
    `.pi/skills/` (`ceec0e3`). Recorded as global finding 5.
  Ruled out: karabiner/README's `remove_files.sh` is the brew cask's own
  script, not a repo path. No repo-local references to
  `pi/.pi/agent/purge/*` remain (AGENTS.md's was fixed in the parent
  pass). Principles 6, 9. Revert: two one-line edits.
- **2026-11-06 Phase 1, hook proposal (drafted, not installed):**
  `.agents/proposals/pre-commit-hook.md` — versioned hook at
  `.agents/hooks/pre-commit`, scoped to `AGENTS.md|.pi/|.agents/` staged
  paths, running check.sh; activation (`git config core.hooksPath`) and
  revert spelled out. Hooks are an owner decision (PLAN open decision 2).
  Principles 2, 10.
- **2026-11-09 owner decisions executed (partly uncommitted, hook live):**
  owner approved three open decisions:
  - **Pre-commit hook installed** (decision 2): `.agents/hooks/pre-commit`
    is live via `git config core.hooksPath .agents/hooks` (no prior hooks
    bypassed — `.git/hooks` held only samples). Verified in three tests:
    data-only staging exits in ~25 ms without running check.sh;
    scaffolding staging runs it; a real violation (AGENTS.md at 34 lines
    vs the 28 budget) blocks the commit with exit 1.
    `.agents/proposals/pre-commit-hook.md` retained as the decision
    record. Principles 2, 10.
  - **AGENTS.md budget accepted at 28** (decision 1) — and the HRM trim
    (below) leaves the file at 19 lines, well under it.
  - **HRM quick-ref lines → progressive disclosure** (decision 3): the
    two HRM/symbol-layer detail lines were deleted from AGENTS.md's
    keyboard section; it now points to `kanata/README.md` and
    `karabiner/README.md`, which already carry the full layout, timings
    and quick-refs. Principle 3 (layering over line-count politics).
  Revert: `git checkout -- AGENTS.md`; for the hook,
  `git config --unset core.hooksPath && rm -r .agents/hooks`.
- **2026-11-09 Phase 3, nvim-theme eased off (owner direction; proposed,
  uncommitted):** owner: "go easier on the nvim skill, I haven't used it
  in months." Usage evidence gathered from session logs and git: real
  sessions that used the skill = only 2026-09-07 and 2026-09-15, the two
  bursts that *built* it; zero use since; the theme itself last touched
  2026-09-18 and stable since. The eval evidence agrees: in the
  tier-change and compare-options misses, agents answered correctly from
  THEME.md without loading the skill. Actions taken:
  - description narrowed to the skill's unique capability (on-screen
    decode + variant verification + candidate comparison), 55 → 48
    words; the redundant triggers ("changing highlight groups,
    treesitter captures or tier rules") were dropped — THEME.md carries
    that knowledge and nvim/README.md already points edit tasks at the
    skill. Two at-risk kept triggers smoke-run once: wrong-colour and
    light-variant both load (the first attempt lost light-variant; fixed
    with a "checking how a tier reads on the other variant" clause).
  - further eval investment in this skill **frozen** at owner direction;
    the suite stays as an on-change smoke test only, no gating runs, no
    replay tasks for it (Phase 5 replay set, if built, draws from other
    repo work).
  - scripts, references and body untouched — they cost nothing standing
    (only descriptions are always-loaded).
  Options deliberately not taken, for the owner: disable model
  invocation (hides the description entirely, manual-only use) or delete
  the skill outright. Principles 1 (selection on human signal + usage
  data), 7. Revert: `git checkout -- .pi/skills/nvim-theme/SKILL.md`.

## Global-scope pass — 2026-11-09

Phases 0–1 applied to the global agent scope (`agents/` = `~/.agents`,
`pi/.pi/agent/`, `claude/`). Repo-local pass (1c74b45..c70c0e2) untouched.

### Phase 0 — inventory and measurements (live session, 2026-11-09)

- **Always-loaded (pi, any repo):** global `pi/.pi/agent/AGENTS.md` 2,482
  chars (~620 tok) + skill descriptions 21 model-invocable skills, 5,773
  chars (~1,443 tok) + harness-owned skills XML wrapper ~877 tok. The
  description block is the largest curatable item in every session —
  finding 3 confirmed, with drift since the 2026-11-05 curation (orbit and
  review-depth added, mr-review merged away).
- **Scopes:** `agents/.agents/skills/` 18 (17 model-invocable;
  agent-scaffolding is manual-only, costs nothing standing);
  `pi/.pi/agent/skills/` 3 (report, subagent, web-browser); repo
  `.pi/skills/` 1 (nvim-theme — done, hands off); `claude/.claude/skills/`
  2 (gitlab-api, orbit). **No same-name collisions in any live scope.**
- **Claude always-loaded:** `~/.claude/CLAUDE.md` carries the orbit-managed
  setup block (~400 tok), outside this repo — orbit owns it, record only.

### Global findings 1–5, verified

1. **purge/ — shadow claim WRONG, dead-weight claim stands.** Verified
   from the live session's 21-skill list: pi does not scan
   `pi/.pi/agent/purge/`, so purged skills shadow nothing. The real risk
   was dangling references — swept: none live (only `.agents/` records).
   Decision proposal: delete the 380K dir (git history keeps it) — see
   `proposals/global-skills-budget.md`.
2. **CONFIRMED, acted on.** `claude/.claude/skills/gitlab-api` was a real
   duplicate, stale since Mar 18, diverged both ways (claude copy held the
   issue-description format; shared copy held early-failure detection,
   fork-remote `--head`, duo-workflows reference). Merged and deduped —
   outcomes below.
3. **CONFIRMED** (see measurement above). Mechanism proposed so it stops
   depending on memory: extend check.sh to global descriptions
   (`proposals/global-hook-scope.md`).
4. **STALE.** `~/workspace/gl/work/ai/AGENTS.md` no longer exists; the
   parent `~/workspace/gl/work/AGENTS.md` (3,540 chars) was restructured
   by that repo's own 2026-11-05 scaffolding pass. Nothing to do here.
5. **CONFIRMED, two more casualties found and fixed** (outcomes below);
   the claude-scope `orbit` symlink had been broken since the Oct 27
   shared-dir restructure (75ec6c3) — claude silently had no orbit skill.

### Outcomes (proposed, uncommitted — one concern per change)

- **2026-11-09 gitlab-api dedupe (finding 2):** ported the claude copy's
  unique content (structured `:robot: AI-generated`
  Problem/Solution/Investigation/Resources issue format) into
  `agents/.agents/skills/gitlab-api/SKILL.md`; description rewritten
  17 → 36 words trigger-style, absorbing the claude copy's better trigger
  terms (pipelines, jobs, MRs, merge trains); `claude/.claude/skills/`
  gitlab-api dir replaced with a symlink to
  `../../../agents/.agents/skills/gitlab-api` (scripts were identical;
  nothing lost). Principles 4, 6. Revert: `git checkout -- agents/
  .agents/skills/gitlab-api/SKILL.md claude/.claude/skills/`.
- **2026-11-09 broken symlinks (finding 5):**
  `claude/.claude/skills/orbit` pointed at `../../.agents/skills/orbit`,
  which resolves to nonexistent `claude/.agents` — broken since 75ec6c3
  moved the shared dir; claude had no orbit skill. Relinked to
  `../../../agents/.agents/skills/orbit`, verified via
  `readlink -f ~/.claude/skills/orbit`. Also removed the dangling
  `~/.claude/token.sh` (target file never existed in git, gone from
  disk). Principles 6, 9. Revert: relink / recreate the symlink.
- **2026-11-09 wait-for dead path (finding 5):** SKILL.md hardcoded
  `$HOME/.pi/agent/skills/wait-for/scripts` — dead since the skill moved
  to `~/.agents/skills/`; the wait examples were un-runnable. Fixed to
  `$HOME/.agents/skills/wait-for/scripts`. Principle 6. Revert: one line.
- **2026-11-09 proposals drafted:** `proposals/global-skills-budget.md`
  (description budgets, 8 rewrites before/after, global AGENTS.md budget
  + git-guard prose trim, purge deletion decision, cheap smoke-eval plan)
  and `proposals/global-hook-scope.md` (extend pre-commit regex + check.sh
  to the global scopes, sequenced after the description fixes land).
  Eval spend capped at ~$5 total for the pass (owner directive,
  2026-11-09) — smoke-runs only, ~$1 for the eight rewrites, anything
  beyond deferred. Principles 2, 3, 4.
- **Dead-pointer sweep, global scope:** all absolute skill-path references
  in every global skill body checked for existence — only the wait-for hit
  (fixed). The gitlab-mr-comments README's `~/.claude/...` mentions are
  upstream install docs, not local pointers. No live references to
  `purge/` or to the researcher/reviewer/worker agents deleted in 43f2f37
  (the subagent skill records the removal as history, correctly).

### Recorded as data, no action

- `pi/.pi/agent/extensions/task.ts` is a symlink into the external `task`
  repo (gitignored, deliberate — that repo owns it); the always-loaded
  task rules in the global AGENTS.md reference a mechanism implemented
  elsewhere. Known setup, not a defect.
- `agents/.agents/skills/gitlab-mr-comments` is a git submodule of the
  published skill; its description edits go upstream.
- `pi/.pi/agent/ANTHROPIC_EDIT_BUG.md` is a doc (not auto-loaded),
  correctly referenced by `edit-guard.ts`.

### Gate

Global Phase 0 gate (human reviews classification/proposals): **pending** —
the two proposals above plus the purge decision are the owner's calls.

## Global-scope pass, session 2 — 2026-11-09 (opus review, decisions, evals)

### Opus review (sub-global-scaffold-review-1794227145)

Verdict: the finished fixes (symlinks, wait-for, gitlab-api merge) all
verified correct; the proposals had real defects. Everything it found was
fixed this session:

- **P1** three rewrites over the 55-word ceiling (task-tabs 56, web-browser
  57, subagent 57 by `wc -w` — a standalone em dash counts as a word);
  tightened to 55/55/54.
- **P2** task-tabs had dropped "close tabs" / "clean up sessions" /
  "what's open" — restored; web-browser keeps rodney/headless/CDP keywords.
- **P2** wrong numbers corrected: 10 (not 8/11) descriptions out of band;
  end state ~5,630 bytes (not ~5,300) — block budget set at 5,600 instead
  of pretending 5,000 is reached; purge deletion saves **zero** tokens
  (never scanned — "headroom" claim removed); git-guard trim saves 3 lines
  (57 → 54), and the revised text keeps the reason clause ("can destroy
  your or other agents' uncommitted work"), which also covers ops the
  extension doesn't block.
- **P1** hook sequencing was wrong: rewrites alone leave the extended
  validator failing on 6 skills. The proposal now lists 4 prerequisites
  (keyword-trigger allowlist, skip `disable-model-invocation`, strip
  `#anchor` in the link check, YAML-parse frontmatter) — a simulation of
  the extended validator over all three scopes now passes.
- **P3** PLAN.md stale scope line fixed; purge note now lists the unique
  archived content (mr-issue-standards, windows-testing, work-context,
  html-report, mermaid, 8 extensions — no live replacement).

### Decisions made (delegated "obvious", per the review's OBVIOUS list)

- **8 description rewrites applied** to the skill files (uncommitted):
  task-tabs 85→55, review-depth 77→53, web-browser 70→55, epub 63→54,
  subagent 62→54, gdk 43→40 trigger-style, web-search 15→38,
  tui-testing 19→35. gitlab-api was already done in session 1.
- **check.sh anchor-strip fix** applied (straight bug: `file.md#anchor`
  links were reported dead; affects the repo-local check today).
- **Trigger smoke evals run** (decision e, ~$5 cap honored — ~33
  case-sessions ≈ $1.5–2 total, including one wasted re-run of the suite
  after I passed an arg the runner ignores; the valid results are the
  12-case suite + 1 follow-up):

  | case | result |
  |---|---|
  | task-tabs-1 / task-tabs-2 | load task-tabs ✓ (incl. near-miss: task-management not loaded) |
  | task-mgmt-near | task-management ✓, task-tabs correctly not loaded |
  | web-browser-1 | load web-browser ✓ |
  | downloads-near | downloads ✓, web-browser correctly not loaded |
  | epub-1 | load epub ✓ |
  | review-depth-1 | review + review-depth both loaded ✓ |
  | subagent-1 | load subagent ✓ |
  | gdk-1 | load gdk ✓ |
  | web-search-1 | nothing loaded, answer correct (GitHub API via curl) — recorded, not tuned (guidelines) |
  | web-search-2 (follow-up) | load web-search ✓ — the rewrite does trigger on a real web-search case |
  | tui-testing-1 | load tui-testing ✓ |
  | gitlab-api-1 | load gitlab-api ✓ |

  No wrong-skill loads, no wrong-answer misses → Phase 3 smoke gate met
  for the rewrites.

### Incident + fix (recorded in the journal)

The first rewrite batch put `: ` (colon+space) inside unquoted YAML plain
scalars ("Keywords: …", "an MR review: validate") — invalid frontmatter;
pi refused to load those three skills and headless eval sessions died
before starting. Tomas hit it live in his session. Fixed same session
(colons → " - "); all 22 SKILL.md files now parse as YAML; validator
prerequisite 4 (YAML-parse frontmatter) added to the hook proposal so the
check would have caught it. Journal:
`2026-11-09-skill-frontmatter-colon-space.md`.

### Still the owner's call (see proposals)

Commit everything (suggested split: verified fixes / rewrites+docs /
check.sh+PLAN); purge deletion; hook+check.sh extension (4 prerequisites,
budget placeholder 60); git-guard prose trim; the stale gitlab-api
description in `~/.gitlab/duo/AGENTS.md` (outside this repo).

## Global-scope pass, session 3 — 2026-11-09 (owner decisions executed)

Tomas's decisions, 2026-11-09: 1 commit (yes), 2 delete purge, 3 hook+
check extension (yes), 4 budget number (delegated → 60), 5 git-guard
trim (yes), 6 delete the stale duo description, 7 further tightening
(delegated). Landed as six commits, one concern each:

- `38a51d7` fix(agents): global-scope dead pointers + claude gitlab-api
  dedupe (symlinks repaired, wait-for path, merge) — session 1 work.
- `230d021` refactor(skills): the 8 trigger-style description rewrites.
- `0b36f06` docs(agents): audit, proposals, journal, plan update.
- `426119a` fix(skills): web-browser back under 55 words — caught by the
  NEW validator while staging the mechanism commit; 230d021 had slipped
  through the old hook's scope gap (agents/ wasn't covered), which is
  the incident proving decision 3's worth. The hook + extended check.sh
  landed next:
- `72b0d83` feat(agents): pre-commit + check.sh cover the global scopes
  (regex extension, three-scope validator, keyword allowlist, manual-only
  skip, anchor strip, colon-space guard — negative-tested; global
  AGENTS.md budget 60).
- `94d98a2` refactor(agents): git-guard prose trim (57 → 52 lines; the
  revised text keeps the reason clause per the opus review).
- `843d3fb` chore(agents): purge/ deleted (never scanned, zero
  references, zero token impact; unique content recoverable in history).

Out-of-repo: `~/.gitlab/duo/AGENTS.md`'s stale gitlab-api description
deleted (bullet now defers to the skill's own frontmatter as source of
truth); the dangling `~/.claude/token.sh` was removed in session 1.

Gardener's own call on decision 7: leave the in-band keyword tails
(fj, pdf, projects) alone — the 5,600-byte budget is met and removing
working triggers without eval evidence violates the selection
principle. Recorded in the proposal's decision note.

Gate: closed for the 2026-11-09 global pass. Open for the next gardener
pass: PLAN decision 6 (nvim-theme zero-use — deliberately deferred), and
re-measuring the description block after a few weeks of the new
validator in force.

## Skill update from the three landed implementations — 2026-11-09

Task `review-scaffold-m9s9d`. Compared the skill's guidelines against the
dotfiles (local + global), work and lifeos implementations; proposed updates
(`.agents/proposals/skill-update-from-implementations.md`), got an Opus
second opinion (subagent `sub-skill-update-review-1794231378` — caught one
wrong citation, one evidence-free item, ~14 missed lessons), applied both.
Landed as itemized edits to `references/guidelines.md` (Phase 0 plan-as-memory
+ parent-stack measurement; Phase 2 provenance-may-live-outside; Phase 3
symlink-dedupe + cross-scope wrong-skill routing; Phase 4 session-log inputs +
confirm-to-proceed guard; Phase 5 pruned-clone + overlay + gate/seed split)
and `references/operational-gotchas.md` (YAML-parse validator rule,
keyword-allowlist, runner isolation/hygiene, true prompts, gate/seed cost
guard, new Replay-acceptance and Guard-design sections). The skill stays
manual-only. Principles 1, 7, 9. Revert: the two commits.
