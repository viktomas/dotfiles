# Agent-scaffolding plan — dotfiles (repo-local scope)

Scoped to this repo's own scaffolding. The global scope (`agents/`,
`pi/.pi/agent/`, `claude/`, `purge/`) gets its own pass later — findings are
recorded as data in `AUDIT.md`, nothing global is touched from here.

- [x] **Phase 0 — baseline audit** (2026-11-06). See `AUDIT.md`.
      Gate: human reviews classification — **pending**.
- [x] **Phase 1 — deterministic guardrails** (2026-11-06, proposed).
      Gap: no CI, no hooks. Nearest equivalent: `.agents/check.sh`
      (budget + skill validator + stow guard). Pre-commit wiring left as an
      owner decision. Gate: check green locally — **pending first run**.
- [x] **Phase 2 — prune AGENTS.md** (2026-11-06, proposed).
      The one S line fixed (stale pointer to the purged `dotfiles` skill);
      scaffolding working-agreement added. Budget: 28 lines, enforced by
      `check.sh` (**placeholder — owner picks**). Provenance: kanata/HRM
      lines point at their READMEs; the `git wta` line is convention.
      Gate: **pending review**.
- [x] **Phase 3 — skills hygiene** (2026-11-06, proposed).
      `nvim-theme`: description 70 → 50 words trigger-style; `compare.py`
      scenario detail layered into `references/compare.md`; evals + runner
      added. No overlaps, no cross-scope shadows of this name.
      Gate: **owner eased off 2026-11-09: description narrowed to the
      skill's unique capability (48 words), kept triggers smoke-verified
      (2/2), dropped triggers intentionally unverified (tier/compare
      questions answer correctly from THEME.md without the skill);
      further eval investment in nvim-theme frozen — residual variance
      accepted. Validator green via `.agents/check.sh`.**
- [ ] **Phase 4 — learning loop.** Journal + working agreement in place.
      Remaining: 2 gardener cycles with ≥1 promotion and ≥1 deletion merged —
      needs scheduled runs, not achievable in one session.
- [ ] **Phase 5 — evals and CI gates.** Seed in AUDIT.md (4 tasks; acceptance
      gap noted — config repo, manual verification, theme scripts only).
      Progress (2026-11-06): sandboxed trigger runner built and the 7-case
      trigger suite's baseline variance measured (see AUDIT.md — single
      runs are noise, gate on ≥3 runs). 2026-11-09: eval investment in
      nvim-theme frozen at owner direction. Remaining: replay tasks from
      the seed (drawn from other repo work), hidden acceptance checks,
      and the gate rule for scaffolding PRs.
- [ ] **Phase 6 — automated harness evolution.** Not requested; skip.

## Open decisions for the owner

1. ~~AGENTS.md line budget: 28 proposed (current 22). Tighten?~~ —
   resolved 2026-11-09: accepted as-is; AGENTS.md is 19 lines after the
   HRM trim, well under budget.
2. ~~Wire `.agents/check.sh` as a pre-commit hook scoped to scaffolding
   paths (`AGENTS.md|.pi/|.agents/`), given there is no CI?~~ —
   resolved 2026-11-09: approved and installed; see
   `.agents/proposals/pre-commit-hook.md`.
3. ~~The two HRM quick-ref lines (borderline I): keep, or move into
   kanata/README.md only?~~ — resolved 2026-11-09: progressive
   disclosure — AGENTS.md keeps a pointer to `kanata/README.md`, the
   quick-ref lines were deleted from AGENTS.md (they already exist in
   kanata/README.md).
4. ~~Phase 5 sandbox~~ — resolved 2026-11-06: `evals/sandbox.sh` built,
   full 7-case suite run, variance recorded in AUDIT.md.
5. ~~nvim-theme description at the 55-word ceiling~~ — resolved
   2026-11-09: narrowed to 48 words when the redundant triggers were
   dropped.
6. nvim-theme has had zero real use since 2026-09-15: if that still holds
   at the next gardener pass, disable model invocation (hides the
   description; manual-only) or delete the skill (scripts would move to
   `nvim/` or `bin/` first — they're the durable asset).
