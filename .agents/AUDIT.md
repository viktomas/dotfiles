# Agent-scaffolding audit — dotfiles (repo-local scope)

Running log for the agent-scaffolding effort (skill:
`~/.agents/skills/agent-scaffolding`) **scoped to this repo's own
scaffolding** — `AGENTS.md`, `.pi/skills/*`, repo mechanisms. The global
agent scope (`agents/` = `~/.agents`, `pi/.pi/agent/` = global pi skills and
extensions, `claude/`, and `pi/.pi/agent/purge/`) is deliberately excluded:
it gets its own pass later. Global findings are recorded below as data.

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
