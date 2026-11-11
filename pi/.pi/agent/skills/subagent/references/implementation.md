# Implementation details

Read this only when debugging the subagent scripts themselves (hung runs,
fleet records, session ids, isolation flags) — not needed to use them.

## Isolation

Subagent `pi` runs without extensions (except `fleet.ts`, see below) and with
only the shared skills (`~/.agents/skills`, the Agent Skills location both pi
and GitLab Duo CLI read), so it cannot spawn further subagents. Don't ask it to
write the task's state file; the parent records what matters there.

The script hardcodes the session dir, the isolation flags and `--`, and wraps
the run in `timeout -k 30` so it can never hang forever.

## Watching the fleet

`task fleet` (or `task fleet --watch 5s` in a zellij tab, `--json` for scripts)
shows every interactive agent and subagent: goal, elapsed/timeout, phase,
current command, and derived states (dead, killed, frozen, stalled-model,
overdue, orphan …). It reads the run records below plus `fleet.ts`'s
`live/`/`ended/` files and the task registry.

Legacy (until `work/scripts/fleet.sh` is retired): each run also writes
`~/.pi/agent/subagent-sessions/active/<pid>.json` and removes it on exit.

## Session ids

`subagent.sh` passes `--session-id sub-<slug>-<epoch>` (epoch = launch time),
so each run is a new session file
`<session-dir>/<timestamp>_sub-<slug>-<epoch>.jsonl`. pi's `No project session
found with id …; creating a new session` stderr warning is filtered out (only
that line). `--resume <id>` checks that `*_<id>.jsonl` exists, then reuses the
id; the run record gets `resumed: true`. `duo-subagent.sh` is unchanged here:
it already has unique run dirs and its own numeric `--resume`.

## Fleet record (observability, contract v1)

Both scripts write `${TASK_FLEET_DIR:-~/.pi/agent/fleet}/runs/<runId>.json`,
`runId = <slug>-<epoch>-<pid>`, atomically (tmp + mv):
`{v, runId, kind: "pi-sub"|"duo", slug, model (resolved id), goal, cwd, sessionId,
startedAt, timeoutS, deadline, scriptPid, resumed, parent: {task, session,
sessionFile, zellijSession, pane ("terminal_<n>"), runId}}`; duo adds `runDir`
and `logFile` (`<runDir>/stderr.log`; `sessionId` is `""` until the run ends,
then the scraped Duo id). Timestamps are ISO-8601 UTC strings; unset values are
`""`, never null. An exit trap adds `endedAt`, `rc`, `timedOut` (pi-sub: timedOut
when rc is 124 or 137; duo: Duo's own exit was 124/137, `rc` is the script's
0/2/3). A run SIGKILLed with its process group (parent Esc/timeout) never gets
those fields. Files are never deleted by the script, except records older than
7 days at launch. Fleet writes are best-effort and never change the exit status.

The `goal` is derived at launch, synchronously (~1s): the prompt (first 8000
chars) is piped to `pi -p --no-session -ne … --model $(pi-model haiku)` with an
instruction to summarize in one line (≤100 chars), falling back to the prompt's
first non-empty line on any failure. `FLEET_GOAL_MODEL=<family>` changes the
model; `FLEET_GOAL_MODEL=` (empty) skips the model call. The scripts export
`FLEET_RUN_ID`, `FLEET_PARENT_SESSION` and `FLEET_DEADLINE` (subagent.sh) to pi;
a nested run records the inherited `FLEET_RUN_ID` as `parent.runId` (duo → its
checker). `subagent.sh` adds `-e ~/.pi/agent/extensions/fleet.ts` only when that
file exists.

## Duo CLI gaps worked around by the script

Fix upstream in gitlab-lsp eventually, then drop the workaround: exit 0 on
lost stream tail / bad turn disposition (read from the log); silent fallback on
an unknown `--model` (watchdog kills the run); no timeout or progress events
(hard timeout + idle watchdog, session id scraped from stderr); failed shell
commands reported as tool success (precheck greps `Exit code: N`); no plan mode
(`--read-only`).
