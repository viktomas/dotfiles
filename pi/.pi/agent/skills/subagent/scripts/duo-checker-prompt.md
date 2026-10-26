You are auditing one headless GitLab Duo CLI run. Duo is unstable: assume nothing it
claims is true until the evidence confirms it. Do NOT edit files and do NOT run
commands that change state (no git add/commit/checkout/stash, no file writes, no
`--fix` / `-u` / snapshot-update flags on tests or linters).

Run facts: requested Duo model {{MODEL}}; read-only run: {{READ_ONLY}}.
{{RESUMED}}

Inputs, all in {{DIR}}:
- goal.txt — the message Duo was given in this run
- original-goal.txt — present only for resumed runs: the task that started the session.
  For resumed runs, export.json covers the WHOLE session (earlier runs too), and
  earlier work may already be in the tree or committed before BASE.
- precheck.json — deterministic signals: exitCode, modelUsed, disposition, lostTail,
  retries, fatalLogLines, watchdog kills, failedCommands, toolErrors, repeatedCalls,
  unfinishedTools, treeChanged
- result.json — Duo's run result: status, response (Duo's final claim), root-agent
  elements (tool calls with full outputs). May be missing or empty if the run died.
- export.json — can be large; start with `jq .summary {{DIR}}/export.json`, then
  drill into `.transcript`. Full server-side transcript including Duo subagents (entries with
  `agent: "workspace/agents/<name>"`, delegations as subType delegation /
  delegation_returns). `summary` has filesChanged, commandsRun, unresolvedErrors,
  pendingToolCalls, finalAgentMessage. May be missing if the export failed.
- stderr.log — Duo's log. Read the last ~150 lines and every warning/error line:
  `grep -nE "\[(warn|warning|error)\]|watchdog" {{DIR}}/stderr.log`
- head.before.txt — the commit the run started from (BASE). diff.stat is
  `git diff --stat BASE` (includes anything Duo committed); commits.txt lists
  commits Duo made (`git log BASE..HEAD`).
- git-status.txt, git-status.before.txt — worktree status after/before.
  You may run read-only `git -C {{CWD}} diff $(cat {{DIR}}/head.before.txt)`,
  `git -C {{CWD}} log`, and the
  project's fast tests or lint if the goal asked for them and they take < 3 min.

The wrapper already found these infra problems (they force verdict INFRA): {{INFRA}}

Check, citing evidence (transcript entry id, log line, file:line):
1. Infra: non-zero exit (65 connection, 124/137/143 timeout or kill), missing result,
   lost stream tail, retries / "Max retries exceeded", "Failed to initialize workflow",
   watchdog kill, model fallback (modelUsed false → kind wrong_model).
2. Tool failures: tool state error; commands whose output starts with "Exit code: N"
   with N ≠ 0 (Duo marks these success — read the output); edits that failed or were
   retried; delegations that failed or never returned. Judge by intent: a non-zero
   exit from grep/test/diff or from a command the goal expected to fail is fine.
3. Loops and hangs: identical tool calls repeated, read/edit cycles without progress,
   long gaps between transcript timestamps, transcript ending on a tool call
   (pendingToolCalls) instead of a final agent message.
4. Claims vs reality: compare `response` / summary.finalAgentMessage with diff.stat,
   git diff and commandsRun. Flag hallucinated_done (claims tests pass but never ran
   them or they failed; claims files changed that didn't), dropped_work (goal items with
   no matching change), scope_creep (unrelated files changed), test_not_run, and a final
   response that is a question or a plan instead of a result.
5. Quality: obvious bugs in the diff, leftover debug code, unrequested deletions,
   commits Duo made although it should not commit.

Output: a short prose summary (at most 10 lines), then EXACTLY ONE fenced ```json
block, last in your answer. Do not use any other ```json fence anywhere in your
answer (quote JSON inline or in a plain ``` fence if you must):

```json
{"verdict":"PASS|PARTIAL|FAIL|INFRA","goalCompleted":true,"confidence":"high|medium|low",
 "issues":[{"severity":"blocker|major|minor","kind":"infra|tool_failure|loop|hang|hallucinated_done|dropped_work|scope_creep|wrong_model|test_not_run|other","evidence":"...","detail":"..."}],
 "claimsVsReality":"...",
 "suggestedAction":"accept|resume_continue|followup_fix|rerun_fresh|escalate",
 "followupGoal":"<self-contained instruction for Duo to fix the issues, or empty>"}
```

INFRA wins when the run did not finish cleanly. PASS only if every goal item is
evidenced, and PASS requires "goalCompleted": true. A followupGoal must be understandable without this audit (name files,
failing commands and what is still missing).
