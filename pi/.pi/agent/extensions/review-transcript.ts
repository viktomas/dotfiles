/**
 * review-transcript Extension
 *
 * `/review-transcript [focus]`
 *
 * Starts a fresh branch of the *current* session whose only context is a
 * rendered transcript of what I saw on screen: user prompts, assistant text,
 * and one-line tool invocations — WITHOUT tool outputs, file contents, or
 * thinking blocks.
 *
 * The point is meta-review, not continuing the work: the reviewing model
 * follows the shape of the conversation (how many detours, how many redundant
 * reads, where instructions were missing) and proposes concrete edits to my
 * agentic config (AGENTS.md, skills, extensions, prompts) — with far fewer
 * tokens than the original branch, because the bulky tool results are gone.
 *
 * Mechanics:
 * 1. Render the transcript from the current branch.
 * 2. `ctx.navigateTree()` back to the start of the session (no summary), which
 *    abandons the current branch in place — the old work stays in the session
 *    tree and is reachable via `/tree`.
 * 3. Send the transcript as a user message on the new branch.
 */

import type {
  ExtensionAPI,
  ExtensionCommandContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";

const MAX_ARG_VALUE_CHARS = 200;
const MAX_TEXT_CHARS = 4000;

function oneLine(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function truncate(value: string, max: number): string {
  return value.length > max ? `${value.slice(0, max)}… [truncated]` : value;
}

function textOf(content: unknown): string {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  const parts: string[] = [];
  for (const block of content) {
    if (!block || typeof block !== "object") continue;
    const b = block as { type?: string; text?: string; mimeType?: string };
    if (b.type === "text" && typeof b.text === "string") parts.push(b.text);
    else if (b.type === "image") parts.push(`[image ${b.mimeType ?? ""}]`.trim());
  }
  return parts.join("\n").trim();
}

/** Render a tool call the way it looks collapsed in the TUI: name + args, one line. */
function renderToolCall(name: string, args: Record<string, unknown> | undefined): string {
  const entries = Object.entries(args ?? {});
  if (entries.length === 0) return `[tool] ${name}()`;
  const rendered = entries
    .map(([key, value]) => {
      const raw = typeof value === "string" ? value : JSON.stringify(value);
      return `${key}: ${truncate(oneLine(raw ?? "undefined"), MAX_ARG_VALUE_CHARS)}`;
    })
    .join(", ");
  return `[tool] ${name}(${rendered})`;
}

function renderEntry(entry: SessionEntry): string | undefined {
  if (entry.type === "compaction") {
    const summary = (entry as unknown as { summary?: string }).summary ?? "";
    return `### [compaction]\n\n${truncate(summary, MAX_TEXT_CHARS)}`;
  }

  if (entry.type !== "message") return undefined;
  const message = (entry as unknown as { message?: Record<string, any> }).message;
  if (!message?.role) return undefined;

  switch (message.role) {
    case "user": {
      const text = textOf(message.content);
      return text ? `### User\n\n${truncate(text, MAX_TEXT_CHARS)}` : undefined;
    }
    case "assistant": {
      const lines: string[] = [];
      const text = textOf(message.content);
      if (text) lines.push(truncate(text, MAX_TEXT_CHARS));
      if (Array.isArray(message.content)) {
        for (const block of message.content) {
          if (block?.type === "toolCall") {
            lines.push(renderToolCall(block.name, block.arguments));
          }
        }
      }
      if (message.stopReason === "aborted") lines.push("[aborted by user]");
      if (message.stopReason === "error") {
        lines.push(`[error] ${oneLine(String(message.errorMessage ?? "unknown"))}`);
      }
      return lines.length > 0 ? `### Assistant\n\n${lines.join("\n\n")}` : undefined;
    }
    case "toolResult": {
      // Outputs are deliberately dropped — only failures are visible when collapsed.
      if (!message.isError) return undefined;
      return `[tool failed] ${message.toolName}: ${truncate(oneLine(textOf(message.content)), MAX_ARG_VALUE_CHARS)}`;
    }
    case "bashExecution": {
      return `### User ran shell\n\n$ ${oneLine(String(message.command ?? ""))}`;
    }
    case "custom": {
      if (!message.display) return undefined;
      const text = textOf(message.content);
      return text ? `### [${message.customType}]\n\n${truncate(text, MAX_TEXT_CHARS)}` : undefined;
    }
    case "branchSummary":
    case "compactionSummary": {
      return `### [${message.role}]\n\n${truncate(String(message.summary ?? ""), MAX_TEXT_CHARS)}`;
    }
    default:
      return undefined;
  }
}

function buildTranscript(branch: SessionEntry[]): string {
  const sections: string[] = [];
  for (const entry of branch) {
    const rendered = renderEntry(entry);
    if (rendered) sections.push(rendered);
  }
  return sections.join("\n\n");
}

function buildPrompt(transcript: string, focus: string): string {
  return [
    "Analyse the transcript of the pi session below and tell me where the agent did NOT work as",
    "efficiently as it could have — then turn those findings into improvements to my agentic setup.",
    "",
    "The transcript is what I saw on screen with every tool call collapsed: user prompts, assistant text,",
    "and one-line tool invocations. Tool outputs, file contents and thinking are NOT included, so you",
    "cannot see what the tools returned. Do not guess their contents — reason about the *shape* of the",
    "session instead. If you need a fact, read the relevant file from disk yourself.",
    "",
    "Be blunt and specific. Quote the step you are talking about. Look for:",
    "- wasted turns: detours, backtracking, dead ends, work that was thrown away",
    "- redundant or avoidable tool calls: re-reading the same file, greps that a single command",
    "  would have answered, exploration that a skill or AGENTS.md line would have short-circuited",
    "- wrong tool for the job, or a cheap check that was skipped and cost a retry later",
    "- context the agent had to rediscover that should have been written down once",
    "- corrections I had to make, misread instructions, missing or ignored conventions",
    "- over-engineering, unrequested work, or verbosity that burned tokens without helping",
    "- the opposite too: places where it should have done MORE (missing verification, no test run)",
    "",
    "For each finding say what happened, why it was inefficient, and what the ideal path would have been.",
    "Where useful, estimate the waste (e.g. 'roughly 4 of 11 tool calls were avoidable').",
    "",
    "Then propose concrete, minimal changes to my configuration so the same waste does not happen again:",
    "- ~/.dotfiles/pi/.pi/agent/AGENTS.md and project AGENTS.md files",
    "- skills in ~/.pi/agent/skills/",
    "- prompts in ~/.pi/agent/prompts/ and extensions in ~/.pi/agent/extensions/",
    "Only propose a change if a rule would have measurably changed this session. Say 'no change needed'",
    "rather than inventing guidance, and prefer editing an existing file over adding a new one.",
    "",
    "Output: (1) a two-line verdict on how efficient the session was overall, (2) the findings, ranked by",
    "wasted effort, (3) a ranked list of proposed edits with exact file paths and the wording you would",
    "add. Ask before writing any file.",
    focus ? `\nExtra focus from me: ${focus}` : "",
    "",
    "<transcript>",
    transcript,
    "</transcript>",
  ]
    .filter((line) => line !== "")
    .join("\n");
}

/** Earliest point we can branch from: just before the first message entry. */
function branchTargetId(branch: SessionEntry[]): string | undefined {
  const firstMessageIdx = branch.findIndex((entry) => entry.type === "message");
  if (firstMessageIdx > 0) return branch[firstMessageIdx - 1].id;
  return branch[0]?.id;
}

function notify(ctx: ExtensionCommandContext, message: string, level: "info" | "warning" | "error") {
  if (ctx.hasUI) ctx.ui.notify(message, level);
  else console.error(message);
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("review-transcript", {
    description: "Branch the session and review its on-screen transcript for agentic-config improvements",
    handler: async (args, ctx) => {
      if (!ctx.isIdle()) {
        notify(ctx, "Agent is busy — wait for the turn to finish", "warning");
        return;
      }

      const branch = ctx.sessionManager.getBranch();
      const transcript = buildTranscript(branch);
      if (!transcript.trim()) {
        notify(ctx, "Nothing to review — the session is empty", "warning");
        return;
      }

      const targetId = branchTargetId(branch);
      if (!targetId) {
        notify(ctx, "Nothing to review — the session is empty", "warning");
        return;
      }

      const prompt = buildPrompt(transcript, args.trim());

      const result = await ctx.navigateTree(targetId, {
        summarize: false,
        label: "review-transcript",
      });
      if (result.cancelled) {
        notify(ctx, "Branching cancelled", "info");
        return;
      }

      pi.sendUserMessage(prompt);
      notify(ctx, "Reviewing transcript on a new branch (old branch is still in /tree)", "info");
    },
  });
}
