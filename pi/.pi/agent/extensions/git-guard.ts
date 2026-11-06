/**
 * Git guard (global)
 *
 * Blocks the forbidden git operations from ~/.pi/agent/AGENTS.md in bash
 * tool calls, with the reason in the block message:
 *   git reset --hard      — destroys uncommitted changes
 *   git checkout . / -- . — destroys uncommitted changes
 *   git clean -f/-fd      — deletes untracked files
 *   git stash             — stashes everyone's changes, not just yours
 *   git add -A / git add .— stages other agents' uncommitted work
 *   git commit --no-verify— bypasses required checks
 *
 * Deliberately NOT overridable by the agent itself: if Tomas wants one of
 * these, he runs it in his own terminal (the prose rule "only on direct
 * user request" cannot be verified by an extension, so the mechanism is
 * stricter than the prose — that's the accepted trade-off).
 *
 * Installed 2026-11-05 from gl/work .agents/drafts/git-guard.ts
 * (agent-scaffolding plan.md Phase 1; the matching AGENTS.md prose was
 * pruned to a pointer in the same change).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FORBIDDEN: { re: RegExp; why: string }[] = [
  { re: /\bgit\s+reset\s+--hard\b/, why: "destroys uncommitted changes" },
  { re: /\bgit\s+checkout\s+(\.\s*$|--\s*\.\s*$)/m, why: "destroys uncommitted changes" },
  { re: /\bgit\s+clean\s+[^&|;]*-[a-zA-Z]*f/, why: "deletes untracked files" },
  { re: /\bgit\s+clean\s+[^&|;]*-[a-zA-Z]*d/, why: "deletes untracked directories" },
  // `stash list` / `stash show` only read
  { re: /\bgit\s+stash\b(?!\s+(list|show)\b)/, why: "stashes ALL changes, including other agents' work" },
  { re: /\bgit\s+add\s+(-A\b|--all\b|\.\s*$)/m, why: "stages other agents' uncommitted work" },
  { re: /\bgit\s+commit\b[^&|;]*--no-verify\b/, why: "bypasses required checks" },
];

/** Commands that execute a string argument as shell code: quoted text there is code. */
const EXECS_STRING = /\b(sh|bash|zsh|fish)\s+-[a-z]*c\b|\beval\b|\bxargs\b|\b(ssh|watch|parallel)\b/;

/**
 * The text the guard matches against. Quoted strings and heredoc bodies are
 * data (commit messages, --evidence "…git stash…", file contents), so they
 * are blanked — unless the command runs a string as code (bash -c, eval,
 * xargs, ssh, …), where quotes are kept and matched (exported for tests).
 */
export function scannable(cmd: string): string {
  if (EXECS_STRING.test(cmd)) return cmd;
  return cmd
    .replace(/<<-?\s*(['"]?)(\w+)\1[^\n]*\n[\s\S]*?\n\s*\2\s*(\n|$)/g, "<<HEREDOC\n")
    .replace(/'[^']*'/g, "''")
    .replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

/** First forbidden match in a bash command, or undefined (exported for tests). */
export function forbidden(cmd: string): string | undefined {
  const text = scannable(cmd);
  return FORBIDDEN.find(({ re }) => re.test(text))?.why;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = String((event.input as Record<string, unknown>)?.command ?? "");
    const why = forbidden(cmd);
    if (!why) return;
    const shown = cmd.trim().length > 200 ? cmd.trim().slice(0, 197) + "…" : cmd.trim();
    return {
      block: true,
      reason:
        `git-guard: blocked — ${shown} ${why}. If Tomas directly requested this exact ` +
        `operation, ask him to run it in his own terminal; agents don't run destructive git ` +
        `ops on shared checkouts. See ~/.pi/agent/AGENTS.md "Forbidden Git Operations".`,
    };
  });
}
