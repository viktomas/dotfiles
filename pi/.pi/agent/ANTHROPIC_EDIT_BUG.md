# The Anthropic edit bug: mangled non-ASCII in tool-call arguments

Researched 2026-10-10. Read this before touching `models.json` or
`extensions/edit-guard.ts`, both of which exist because of it.

## Symptom

Claude models (Opus 5, Opus 5.5, Sonnet 5, Fable 5.x) write non-ASCII
characters into `edit`/`write` arguments in a broken form:

| intended | what arrives in the decoded argument |
|---|---|
| `—` | the six characters `\u2014` |
| `€5,306.66` | newline + `e5,306.66` (escape lost its `u20ac`, became `\n` + `e`) |
| `—` | `\b0b4`, `\f2014`: a control character + leftover hex digits |
| `—` | `""` |

In `oldText` this fails with "Could not find the exact text". In `newText` it
**succeeds and writes the garbage to disk**. The model then spends calls cleaning
up after itself (`grep u2014`, re-reads, fix-up edits). Once the garbage is in a
file, re-reading it makes the next escape more likely (42% vs 14% hit rate).

An AGENTS.md rule ("write non-ASCII literally", added 2026-09-25) had **no
measurable effect**. The model is not choosing to write the escape.

## Root cause: pi's strict tool mode (grammar-constrained sampling)

- pi **0.86.0** (2026-09-19) enabled `constrainedSampling: { strict: "prefer" }`
  for the built-in `read`/`bash`/`edit`/`write` tools
  (`pi-coding-agent/dist/core/tools/edit.js:89` etc.; CHANGELOG 0.86.0).
- `pi-ai/dist/providers/data/anthropic.json` marks every Claude model
  `compat.supportsStrictTools: true`, so `anthropic-messages.js` (`convertTools`)
  sends `strict: true` on every tool.
- Under strict mode Anthropic samples the tool input against a JSON grammar. The
  model still reaches for a JSON `\uXXXX` escape, the grammar won't accept `u`
  after a backslash, so the sampler picks another escape letter (`\\`, `\n`,
  `\b`, `\f`) and the hex digits come out as plain text. All four shapes above
  follow from this.
- Not the cause: `eager_input_streaming` (on long before, Opus 4.6/4.8 at
  ~0.1%), pi's JSON repair or `prepareEditArguments` (they only *accept* these
  strings, because they are valid JSON).
- Without strict mode the model still writes `\u20ac` in the raw JSON, but it
  is a *valid* escape and decodes to `€`. Harmless.

## Evidence

My sessions (3,901 jsonl files, `.md` edit/write calls containing non-ASCII):

| model | before 2026-09-22 09:16Z | after (pi ≥ 0.87.0) |
|---|---|---|
| claude-opus-5 | 0 / 1278 | 8 / 122 (6.6%) |
| claude-sonnet-5 | 0 / 247 | 46 / 192 (24%) |
| claude-opus-5-5 | (not used) | 122 / 565 (21.6%) |
| claude-opus-4-6 | 2 / 2020 | (not used) |

The first hit came 5 minutes after the upgrade from 0.85.1 to 0.87.0. The
rate is 10% below 50k context tokens and about 30% above 100k.

Upstream:
- earendil-works/pi#10074 (open): same bug, traced to strict sampling. Setting
  `supportsStrictTools: false` dropped mangled args from **9.5% to 1.5%** and
  "Could not find" misses from 7.1% to 1.5%.
  <https://github.com/earendil-works/pi/issues/10074>
- anthropics/anthropic-sdk-python#1926 (open): reproduces it on the raw API with
  Sonnet 5 strict tool calls, no harness involved.
  <https://github.com/anthropics/anthropic-sdk-python/issues/1926>
- Claude Code ships an auto-unescape pass, which caused its own bugs (#72957,
  #99361: you can't write a real `\uE010`; every char written escaped). Lesson:
  **block, don't auto-unescape.**

## What is in place

1. **`models.json`**: `providers.anthropic.compat.supportsStrictTools: false`.
   This removes the grammar, which is the actual fix. Because it is config, not
   an extension, it also covers subagents (`pi -ne`). If Claude is ever used
   through another provider (e.g. GitLab Duo), add the same `compat` there.
2. **`extensions/edit-guard.ts`** catches what is left (main session only):
   - blocks `edit`/`write` whose arguments contain a C0 control character, or a
     literal `\uXXXX` in a prose/data file, unless that exact sequence is
     already in the target file. The block reason tells the model it is an
     encoding error and points here.
   - blocks `sed -i`/`perl -i`/python|node read-replace-write rewrites of files
     outside `/tmp`. This is a separate model habit, unrelated to the encoding bug:
     Opus 5.5 does it for ~17% of its edit volume, and an AGENTS.md ban only
     halved it for Opus 5.

   It cannot catch `""` or newline + letter. Those look like real text, and
   only fix 1 prevents them.

The guard does **not** reject correctly encoded edits: pi decodes valid JSON
escapes before extensions run, so a good edit contains `€`, never `\u20ac`.

## When to revisit

- A pi release that fixes strict-mode escaping for Anthropic (watch #10074),
  or Anthropic fixing it server-side (#1926). Then `models.json` can go.
- Check the hit rate: grep sessions for `edit-guard: blocked` and for
  `\\u[0-9a-f]{4}` in `.md` edit arguments. It should be ~1–2%.
- One-off cleanup of damage that already landed:
  `rg -n '\\u[0-9a-fA-F]{4}|[\x08\x0c]' --glob '*.md'` per repo.
