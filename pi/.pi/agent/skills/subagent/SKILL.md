---
name: subagent
description: Spawn a one-shot subagent in a separate session to investigate or research without polluting the main context. Use when a question obviously doesn't need your current full context. Also runs GitLab Duo CLI headless, auto-checked by a pi Sonnet reviewer — use whenever I say duo subagent, run duo, send duo, delegate to duo.
---

# Subagent

Run a headless `pi` for work that need not live in the main conversation. The
subagent has its own context; its final answer is the script output.

When the user says "use subagents" for a task, it holds for the whole task: hand every
multi-file code investigation (more than ~3 reads/greps) to a subagent that returns a
short answer with file:line refs, not just the opening research.

## Invocation

```bash
~/.pi/agent/skills/subagent/scripts/subagent.sh --slug <slug> [--model <model>] "<task>"
```

- `--slug <slug>` — short descriptive id, `[a-z0-9-]` only (e.g. `lsp-auth`).
  Becomes the display name and part of the session id `sub-<slug>-<epoch>`
  (unique per run; reusing a slug no longer appends to an old session).
- `--model <model>` — optional, defaults to `sonnet`. A **family name**, resolved
  through the `pi-model` alias table (`~/.dotfiles/bin/pi-model`, on `$PATH` as
  `pi-model`), or a full model id, which passes through unchanged. The ids behind
  the names live in that one file; bump them there, never here.
  - `glm` — fast glm; use for analysis and cheap bulk work unless I explicitly
    said I'm away from the keyboard, then use `sonnet`
  - `sonnet` — implementation and slower analysis
  - `opus` — complex subtask delegation where it's expected to resolve higher
    uncertainty
  - `pi-model <family>:<thinking>` also takes a thinking level, e.g. `opus:high`
- `--timeout <seconds>` — optional, defaults to `600`. Raise it for long
  investigations; the run is killed when it expires.
- prompt — positional, or piped on stdin for long multi-line tasks:

```bash
echo "$long_prompt" | ~/.pi/agent/skills/subagent/scripts/subagent.sh --slug lsp-auth
```

- `--resume <sessionId>` — optional. Continues an earlier session on purpose
  (new prompt, full previous context). Pass the id from the `session:` line of
  that run. Fails fast (exit 1) if no such session exists. Without it every run
  starts a fresh session, even with a reused `--slug`.

Every run ends with `subagent.sh: session: sub-<slug>-<epoch> (<file>)` on
stderr (success or failure), so capture stderr (`2>&1` or a file) when you may
want to resume or inspect it. The goal shown in the fleet view is derived
automatically (haiku summary of the prompt); callers pass nothing extra.

## Parallel research

Independent **research** subagents may run in parallel. Do **not** parallelize
subagents that modify files — run those one at a time.

```bash
S=~/.pi/agent/skills/subagent/scripts/subagent.sh
$S --slug topic-a "Question A" > /tmp/sub_a.txt 2>&1 &
$S --slug topic-b "Question B" > /tmp/sub_b.txt 2>&1 &
wait; cat /tmp/sub_a.txt /tmp/sub_b.txt
```

## Analyse → implement → review cycle

For "implement X as separate MRs using subagents": one cycle per MR, one MR at
a time. The parent orchestrates and owns git: worktree, commit, push, MR.

1. **Analyse** (read-only): the subagent returns findings and a concrete plan
   (files, steps, tests to run). Tell it not to edit anything.
2. **Implement** (`sonnet`, `--timeout 1800`): create the worktree
   first (`git-worktree` skill), then pass the plan and the worktree path. It
   edits and runs the tests there, and does not commit. Never two at once.
3. **Review** (a fresh subagent that never saw the implementer's reasoning):
   pass the plan and the worktree path. It checks `git diff` against the plan,
   runs the tests, and reports issues as a list. No edits.
4. **Parent**: fix small issues yourself, or hand the review to a new implement
   subagent and repeat 3. After two loops without a clean review, ask the user.
   Then commit, push and open the MR.

Subagents share no context: pass each one the previous step's output verbatim
(on stdin) plus the worktree path.

## Duo subagents

When I ask for **duo subagents** ("run duo", "send duo opus", "let duo do it"),
run the task in GitLab Duo CLI headless instead of pi. Every run is audited
automatically: the script prechecks Duo's logs and output, exports the full Duo
transcript, and sends a pi `sonnet` checker over it. Duo is unstable, so never
trust its own answer; act on the verdict.

```bash
~/.pi/agent/skills/subagent/scripts/duo-subagent.sh --slug <slug> --cwd <worktree> \
  [--model sonnet|opus|<duo id>] [--timeout 3600] [--idle 900] \
  [--resume <sessionId>] [--read-only] [--no-check] "<goal>"   # or goal on stdin
```

- `--cwd` is required: the worktree Duo works in. Create it first
  (`git-worktree` skill). One Duo run per worktree.
- `--model`: `sonnet` (default, implementation) or `opus` (hard or ambiguous
  work); mapped to Duo ids `claude_sonnet_5_5` / `claude_opus_5_5` at the top of
  the script. A full Duo `gitlab_identifier` passes through.
- `--read-only` for analysis: Duo headless has no plan mode, so the goal gets a
  read-only preamble and the run fails if the worktree changed.
- `--resume <sessionId>` continues an existing Duo session with a new goal. It
  reuses the model of the run that started the session (unless `--model` is
  given), and the checker judges against that run's original goal.
- `--timeout` is a hard limit. `--idle` kills the run when Duo's log is silent
  that long; model turns are silent, so keep it ≥ 600.
- Goals are self-contained (Duo shares no context). Implementation goals always
  say "do not commit" and name the tests or lint to run.
- The checker takes a few minutes; give the bash call a timeout of
  `--timeout` + 1500. Killing the bash call (timeout/Esc) also kills Duo.

**Output:** the checker's prose, then one final JSON line (also in
`<dir>/verdict.json`):
`{dir, sessionId, model, exitCode, readOnlyViolated, commits, verdict, goalCompleted, suggestedAction, followupGoal, issues}`.
Exit status is 0 for `PASS`, 2 for any other verdict, 3 if the script crashed.
`commits` > 0 means Duo committed despite being told not to: check `commits.txt`.

**Verdicts and what to do:**

| verdict / action | Do |
|---|---|
| `PASS` / `accept` | Glance at `git diff` and run the tests yourself, then carry on (commit/MR is yours). |
| `PARTIAL`/`FAIL` + `followup_fix` | `--resume <sessionId>` with `followupGoal` as the goal. At most 2 loops. |
| `INFRA` + `resume_continue` | `--resume <sessionId> "Continue the previous task. If it is already done, restate the final result and list the changed files."` once. If that says the session has ended, run fresh with the original goal plus the current `git diff --stat`. |
| `INFRA` + `rerun_fresh` (`wrong_model`) | Duo silently replaced the model; the run was killed. Rerun with a valid id. |
| `INFRA` + `rerun_fresh` (session ended) | The session can't be resumed. Run fresh with the original goal plus the current `git diff --stat`. |
| `PARTIAL`/`FAIL` + `rerun_fresh` | Duo went off the rails; run fresh with a sharper goal. Counts as a loop. |
| `readOnlyViolated: true` | A `--read-only` run changed the worktree. Inspect `git status`/`git diff` and revert Duo's changes before anything else. |
| `UNCHECKED` (`--no-check`) | No audit ran; check the result yourself. |
| `UNKNOWN` / `escalate`, or still failing after the loops | Stop. Record the run dir in the task state, end with `GATE: review`. |

**Parallel:** unlike pi implementers, Duo runs that edit files may run in parallel
when each has its own worktree. Cap at 3–4 (credits, MCP servers per run).

```bash
D=~/.pi/agent/skills/subagent/scripts/duo-subagent.sh
$D --slug fix-a --cwd ../fix-a --model opus "..." > /tmp/duo_a.txt 2>&1 &
$D --slug fix-b --cwd ../fix-b "..." > /tmp/duo_b.txt 2>&1 &
wait; tail -n 30 /tmp/duo_a.txt /tmp/duo_b.txt
```

In the analyse → implement → review cycle, a Duo run can replace any step. The
built-in checker audits the *run* (infra, tool failures, claims vs diff); for MR
quality still use a separate review subagent.

**Duo's own subagents:** none are configured. Agent-definition files
(`~/.pi/agent/agents/*.md`, the `--agents` merge) were removed 2026-11-06 as
unused — AGENTS.md (`~/.gitlab/duo/AGENTS.md` + repo `AGENTS.md`) and the shared
`~/.agents` skills are the only instruction sources. If a goal needs a
specialist protocol, describe it in the goal text or in AGENTS.md.

**Run artifacts** in `~/.pi/agent/duo-runs/<timestamp>-<slug>.XXXX/`: `goal.txt`,
`original-goal.txt` (resumed runs), `model.txt`, `cmd.txt`, `head.before.txt`, `commits.txt`, `stderr.log` (Duo's log; headless Duo writes no log file itself),
`result.json`, `export.json` (full transcript incl. subagents, with `summary`),
`precheck.json`, `diff.stat`, `git-status*.txt`, `check.md`, `verdict.json`. The
checker's prompt is `checker-prompt.md`; its pi transcript is
`~/.pi/agent/subagent-sessions/*sub-duo-check-<timestamp>-<slug>-*.jsonl`.
The Duo session is also visible on GitLab (Automate → Agent sessions).
Duo CLI gaps the script works around are listed in
[references/implementation.md](./references/implementation.md).

## Debugging a hung or failed subagent

On failure the script prints the exit reason and the session file path to stderr.
Inspect that transcript — the last entry is the step it hung on:

```bash
F=$(ls -t ~/.pi/agent/subagent-sessions/*_sub-<slug>-*.jsonl | head -1)  # or the path on the `session:` line

# timeline: role / tool calls, no bulky text
jq -rc 'select(.type=="message") | [.timestamp, .message.role,
  ((.message.content[]? | select(.type=="toolCall") | .name) // "-")] | @tsv' "$F"

# full detail of the last few entries
tail -3 "$F" | jq .
```

While a subagent is still running you can watch it live with `tail -f` on the
same file.

To browse subagent sessions on purpose (they are kept outside
`~/.pi/agent/sessions/`, so they never show up in `/resume` or `pi -r`):

```bash
pi -r --session-dir ~/.pi/agent/subagent-sessions
```

## Implementation details

Internals of the scripts — isolation, session ids, fleet run records, goal
derivation. Read only when debugging a run that misbehaves:
[references/implementation.md](./references/implementation.md).
