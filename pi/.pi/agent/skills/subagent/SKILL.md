---
name: subagent
description: Spawn a one-shot subagent in a separate session to investigate or research something without polluting the main context. Use when answering a question obviously doesn't need your current full context. Also runs GitLab Duo CLI (glab duo cli) headless as a subagent, auto-checked by a pi Sonnet reviewer - use whenever I say duo subagent, run duo, send duo, delegate to duo.
---

# Subagent

Run a headless `pi` for work that need not live in the main conversation. The
subagent has its own context; its final answer is the script output.

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

**Duo's own subagents:** put personal agents in `~/.pi/agent/duo-agents/<name>.md`
(frontmatter `name`, `description`, `tools` as list or comma string; body =
prompt). The script merges them with the repo's `.agents/agents/*.md` (repo wins
on name clashes) and passes them via `--agents`; Duo itself only reads the repo
dir. All Duo subagents use the run's model (Duo has no per-agent model). Ask
Duo to "delegate to the <name> subagent" in the goal.

**Run artifacts** in `~/.pi/agent/duo-runs/<timestamp>-<slug>.XXXX/`: `goal.txt`,
`original-goal.txt` (resumed runs), `model.txt`, `cmd.txt`, `agents.json`,
`agents-dropped.txt` (agent files that failed to parse), `head.before.txt`, `commits.txt`, `stderr.log` (Duo's log; headless Duo writes no log file itself),
`result.json`, `export.json` (full transcript incl. subagents, with `summary`),
`precheck.json`, `diff.stat`, `git-status*.txt`, `check.md`, `verdict.json`. The
checker's prompt is `checker-prompt.md`; its pi transcript is
`~/.pi/agent/subagent-sessions/*sub-duo-check-<timestamp>-<slug>-*.jsonl`.
The Duo session is also visible on GitLab (Automate → Agent sessions).

**Duo gaps worked around by the script** (fix upstream in gitlab-lsp
eventually, then drop the workaround): exit 0 on lost stream tail / bad turn
disposition (read from the log); silent fallback on an unknown `--model`
(watchdog kills the run); no timeout or progress events (hard timeout + idle
watchdog, session id scraped from stderr); failed shell commands reported as
tool success (precheck greps `Exit code: N`); no plan mode (`--read-only`); no
user-level agents (merged from `~/.pi/agent/duo-agents`).

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

## Implementaion details (ignore unless debugging)
Subagent `pi` runs without extensions and with only the shared skills (`~/.agents/skills`,
the Agent Skills location both pi and GitLab Duo CLI read), so it
cannot spawn further subagents. Don't ask it to write the task's state file;
the parent records what matters there.

Each run registers itself in `~/.pi/agent/subagent-sessions/active/<pid>.json`
(slug, model, parent task from `$TASK_ID`, goal, start time) and removes the
file on exit — so the file's presence means "running". `work/scripts/fleet.sh`
renders the fleet from those files plus `task list --json`.

The script hardcodes the session dir, the isolation flags and `--`, and wraps the
run in `timeout -k 30` so it can never hang forever.

**Session ids.** `subagent.sh` passes `--session-id sub-<slug>-<epoch>` (epoch =
launch time), so each run is a new session file
`<session-dir>/<timestamp>_sub-<slug>-<epoch>.jsonl`. pi's `No project session
found with id …; creating a new session` stderr warning is filtered out (only
that line). `--resume <id>` checks that `*_<id>.jsonl` exists, then reuses the
id; the run record gets `resumed: true`. `duo-subagent.sh` is unchanged here: it
already has unique run dirs and its own numeric `--resume`.

**Fleet record** (observability, contract v1). Both scripts write
`${TASK_FLEET_DIR:-~/.pi/agent/fleet}/runs/<runId>.json`, `runId =
<slug>-<epoch>-<pid>`, atomically (tmp + mv):
`{v, runId, kind: "pi-sub"|"duo", slug, model (resolved id), goal, cwd, sessionId,
startedAt, timeoutS, deadline, scriptPid, resumed, parent: {task, session,
sessionFile, zellijSession, pane ("terminal_<n>"), runId}}`; duo adds `runDir`
and `logFile` (`<runDir>/stderr.log`; `sessionId` is `""` until the run ends,
then the scraped Duo id). Timestamps are ISO-8601 UTC strings; unset values are
`""`, never null. An exit trap adds `endedAt`, `rc`, `timedOut` (pi-sub: timedOut when rc is
124 or 137; duo: Duo's own exit was 124/137, `rc` is the script's 0/2/3). A run
SIGKILLed with its process group (parent Esc/timeout) never gets those fields.
Files are never deleted by the script, except records older than 7 days at
launch. Fleet writes are best-effort and never change the exit status.

The `goal` is derived at launch, synchronously (~1s): the prompt (first 8000
chars) is piped to `pi -p --no-session -ne … --model $(pi-model haiku)` with an
instruction to summarize in one line (≤100 chars), falling back to the prompt's
first non-empty line on any failure. `FLEET_GOAL_MODEL=<family>` changes the
model; `FLEET_GOAL_MODEL=` (empty) skips the model call. The scripts export
`FLEET_RUN_ID`, `FLEET_PARENT_SESSION` and `FLEET_DEADLINE` (subagent.sh) to pi;
a nested run records the inherited `FLEET_RUN_ID` as `parent.runId` (duo → its
checker). `subagent.sh` adds `-e ~/.pi/agent/extensions/fleet.ts` only when that
file exists.
