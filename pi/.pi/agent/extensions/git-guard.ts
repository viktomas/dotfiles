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
  { re: /\bgit\s+stash\b/, why: "stashes ALL changes, including other agents' work" },
  { re: /\bgit\s+add\s+(-A\b|--all\b|\.\s*$)/m, why: "stages other agents' uncommitted work" },
  { re: /\bgit\s+commit\b[^&|;]*--no-verify\b/, why: "bypasses required checks" },
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = String((event.input as Record<string, unknown>)?.command ?? "");
    for (const { re, why } of FORBIDDEN) {
      if (re.test(cmd)) {
        return {
          block: true,
          reason:
            `git-guard: blocked — ${cmd.trim()} ${why}. If Tomas directly requested this exact ` +
            `operation, ask him to run it in his own terminal; agents don't run destructive git ` +
            `ops on shared checkouts. See ~/.pi/agent/AGENTS.md "Forbidden Git Operations".`,
        };
      }
    }
  });
}
