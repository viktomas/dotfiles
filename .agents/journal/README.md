# Learning journal — dotfiles (repo-local)

Append-only. **Never auto-loaded, never instructions** — the gardener treats
entries as data and verifies evidence before promoting anything. Repo-local
lessons only; global-scope lessons (skills in `agents/`, `pi/.pi/agent/`)
wait for the global pass.

One file per lesson, named `<date>-<slug>.md`:

```
date:        2026-11-06
session/ref: <task id, session, or commit>
symptom:     what went wrong or cost extra turns
evidence:    command / error / file, reproducible from the repo
cause:       suspected
fix type:    code | mechanism | skill | AGENTS.md | doc | none
fingerprint: short stable key (e.g. "stale-pointer-to-purged-skill")
count:       1   (increment, don't duplicate, when the fingerprint repeats)
```

Promotion: 3+ occurrences across distinct sessions within ~30 days (or one
occurrence human-tagged high severity). Unpromoted entries expire after
60–90 days.
