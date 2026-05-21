/**
 * HTML Report Extension
 *
 * Provides `/report` and `/annotations` commands that use pi's tree branching
 * to isolate HTML report generation from the main conversation.
 *
 * Flow:
 * 1. Discussion reaches a natural point (point A)
 * 2. `/report [optional focus]` — branches from HEAD, injects report generation instructions
 * 3. LLM generates report with full context, user reviews in browser
 * 4. User exports annotations from the browser, pastes them
 * 5. `/annotations [pasted text]` — LLM translates annotations with full report context,
 *    then navigates back to point A and sends the translated feedback as a user message
 * 6. Main branch LLM continues with clean analytical context + feedback
 */

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { BorderedLoader, Text } from "@earendil-works/pi-tui";
import path from "node:path";
import { promises as fs } from "node:fs";

// ── State ──

const REPORT_STATE_TYPE = "html-report-session";

type ReportSessionState = {
  active: boolean;
  originId?: string;
};

let reportOriginId: string | undefined;

// ── Skill directory (co-located with the existing skill resources) ──

const SKILL_DIR = path.join(
  process.env.HOME ?? "~",
  ".pi/agent/skills/html-report",
);

// ── Widget ──

function setReportWidget(ctx: ExtensionContext, active: boolean) {
  if (!ctx.hasUI) return;
  if (!active) {
    ctx.ui.setWidget("html-report", undefined);
    return;
  }

  ctx.ui.setWidget("html-report", (_tui, theme) => {
    const text = new Text(
      theme.fg(
        "warning",
        "Report branch active — use /annotations to return with feedback, or /end-report to discard",
      ),
      0,
      0,
    );
    return {
      render(width: number) {
        return text.render(width);
      },
      invalidate() {
        text.invalidate();
      },
    };
  });
}

function getReportState(
  ctx: ExtensionContext,
): ReportSessionState | undefined {
  let state: ReportSessionState | undefined;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "custom" && entry.customType === REPORT_STATE_TYPE) {
      state = entry.data as ReportSessionState | undefined;
    }
  }
  return state;
}

function applyReportState(ctx: ExtensionContext) {
  const state = getReportState(ctx);
  if (state?.active && state.originId) {
    reportOriginId = state.originId;
    setReportWidget(ctx, true);
    return;
  }
  reportOriginId = undefined;
  setReportWidget(ctx, false);
}

// ── Report prompt builder ──

async function buildReportPrompt(userFocus?: string): Promise<string> {
  let template: string;
  try {
    template = await fs.readFile(
      path.join(SKILL_DIR, "resources/template.html"),
      "utf8",
    );
  } catch {
    template = "(template not found — use a basic HTML dark theme)";
  }

  const injectScript = path.join(SKILL_DIR, "tools/inject-annotations.sh");

  const focusLine = userFocus
    ? `\n## Focus\n\n${userFocus}\n`
    : "";

  return `Generate an HTML report based on our discussion.
${focusLine}
## Workflow

1. Create a temp directory: \`/tmp/<descriptive-name>/\`
2. If using Mermaid diagrams, validate .mmd files with the mermaid skill before embedding
3. Write \`report.html\` using the template below as a starting point
4. **Finalize**: \`${injectScript} /tmp/<descriptive-name>/report.html\` — mandatory before opening
5. Open: \`open /tmp/<descriptive-name>/report.html\`

**Never skip step 4.** Never open a report without running the inject script first.

## Template

Use this as a **starting point only** — adapt, extend, add custom CSS as needed:

\`\`\`html
${template}
\`\`\`

## Mermaid Escaping

Mermaid renders client-side. The \`<pre class="mermaid">\` content is parsed as HTML first, then by Mermaid.
You **must** use Mermaid entity escapes (NOT \`&\`-prefixed HTML entities):

| Character | Mermaid escape |
|-----------|---------------|
| \`#\` | \`#35;\` |
| \`"\` | \`#quot;\` |
| \`;\` | \`#59;\` |
| Line break | \`#lt;br/#gt;\` |

## Syntax Highlighting

highlight.js is loaded from CDN. Add language packs you need:
\`\`\`html
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/typescript.min.js"></script>
\`\`\`

## Rules

- **Always use \`/tmp/\`** — reports are ephemeral artifacts, not project files
- **Always finalize before opening** — the inject script must run on every report
- **Self-contained** — no local asset references; use CDN for libraries
- Don't limit yourself to the template — add custom styles, layouts, animations as needed`;
}

// ── Annotation translation prompt ──

const ANNOTATION_TRANSLATE_PROMPT = `The user reviewed the HTML report and left annotations. Your job is to translate these annotations into feedback that makes sense in the context of the original discussion — NOT in the context of the HTML report.

Write a concise summary of the user's feedback. Reference the topics, concepts, and decisions from the discussion — not HTML sections, report layout, or visual elements. The recipient has never seen the report.

Format as a bulleted list of actionable feedback points. Be direct and specific.

Here are the annotations:

`;

// ── Extension ──

export default function htmlReportExtension(pi: ExtensionAPI) {
  // Restore state on session events
  pi.on("session_start", (_event, ctx) => {
    applyReportState(ctx);
  });

  pi.on("session_switch", (_event, ctx) => {
    applyReportState(ctx);
  });

  pi.on("session_tree", (_event, ctx) => {
    applyReportState(ctx);
  });

  // ── /report ──

  pi.registerCommand("report", {
    description:
      "Branch from current position and generate an HTML report (accepts optional focus text)",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("report requires interactive mode", "error");
        return;
      }

      if (reportOriginId) {
        ctx.ui.notify(
          "Already in a report branch. Use /annotations to return, or /end-report to discard.",
          "warning",
        );
        return;
      }

      // Store current position
      const originId = ctx.sessionManager.getLeafId() ?? undefined;
      if (!originId) {
        ctx.ui.notify("No session position to branch from.", "error");
        return;
      }

      reportOriginId = originId;
      const lockedOriginId = originId;

      // Navigate to current position to create a branch
      try {
        const result = await ctx.navigateTree(originId, {
          summarize: false,
          label: "report",
        });
        if (result.cancelled) {
          reportOriginId = undefined;
          return;
        }
      } catch (error) {
        reportOriginId = undefined;
        ctx.ui.notify(
          `Failed to create report branch: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
        return;
      }

      // Restore origin after navigation events
      reportOriginId = lockedOriginId;

      // Clear editor
      ctx.ui.setEditorText("");

      // Show widget
      setReportWidget(ctx, true);

      // Persist state
      pi.appendEntry(REPORT_STATE_TYPE, {
        active: true,
        originId: lockedOriginId,
      });

      // Build and send the report generation prompt, with optional user focus
      const userFocus = args?.trim() || undefined;
      const prompt = await buildReportPrompt(userFocus);
      ctx.ui.notify("Report branch created. Generating report...", "info");
      pi.sendUserMessage(prompt);
    },
  });

  // ── /annotations ──

  pi.registerCommand("annotations", {
    description:
      "Send annotations to LLM for translation, then return to main branch with feedback",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("annotations requires interactive mode", "error");
        return;
      }

      // Check if we're in a report branch
      if (!reportOriginId) {
        const state = getReportState(ctx);
        if (state?.active && state.originId) {
          reportOriginId = state.originId;
        } else {
          ctx.ui.notify(
            "Not in a report branch. Use /report first.",
            "info",
          );
          return;
        }
      }

      // Get annotations: from args (pasted inline) or from editor
      let rawAnnotations = args?.trim() || undefined;

      if (!rawAnnotations) {
        rawAnnotations =
          (
            await ctx.ui.editor(
              "Paste exported annotations (from the 📋 Export button in the report):",
              "",
            )
          )?.trim() || undefined;
      }

      if (!rawAnnotations) {
        ctx.ui.notify(
          "No annotations provided. Staying on report branch.",
          "info",
        );
        return;
      }

      // Send annotations to LLM on the report branch for translation
      // The LLM has full context of both the discussion AND the report
      const translationPrompt =
        ANNOTATION_TRANSLATE_PROMPT + rawAnnotations;

      pi.sendUserMessage(translationPrompt);

      // Wait for the LLM to finish translating
      await ctx.waitForIdle();

      // Extract the LLM's translation from the last assistant message
      const branch = ctx.sessionManager.getBranch();
      let translatedFeedback: string | undefined;

      for (let i = branch.length - 1; i >= 0; i--) {
        const entry = branch[i];
        if (
          entry.type === "message" &&
          entry.message.role === "assistant"
        ) {
          // Extract text content from the assistant message
          const content = entry.message.content;
          if (typeof content === "string") {
            translatedFeedback = content;
          } else if (Array.isArray(content)) {
            translatedFeedback = content
              .filter(
                (c): c is { type: "text"; text: string } =>
                  c.type === "text",
              )
              .map((c) => c.text)
              .join("\n");
          }
          break;
        }
      }

      if (!translatedFeedback?.trim()) {
        ctx.ui.notify(
          "Could not extract translated feedback. Staying on report branch.",
          "warning",
        );
        return;
      }

      ctx.ui.notify("Feedback translated. Returning to main branch...", "info");

      const originId = reportOriginId;

      // Navigate back to origin without summary — we have our own translated feedback
      try {
        const result = await ctx.navigateTree(originId!, {
          summarize: false,
        });

        if (result.cancelled) {
          ctx.ui.notify(
            "Navigation cancelled. Use /annotations to try again.",
            "info",
          );
          return;
        }

        // Clear state
        setReportWidget(ctx, false);
        reportOriginId = undefined;
        pi.appendEntry(REPORT_STATE_TYPE, { active: false });

        // Send the LLM-translated feedback as a user message on the main branch
        pi.sendUserMessage(
          `I reviewed a report of our discussion and have the following feedback:\n\n${translatedFeedback}`,
        );

        ctx.ui.notify(
          "Back on main branch with your feedback injected.",
          "info",
        );
      } catch (error) {
        ctx.ui.notify(
          `Failed to return: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
      }
    },
  });

  // ── /end-report ──

  pi.registerCommand("end-report", {
    description:
      "Leave report branch and return to main branch without annotations",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("end-report requires interactive mode", "error");
        return;
      }

      if (!reportOriginId) {
        const state = getReportState(ctx);
        if (state?.active && state.originId) {
          reportOriginId = state.originId;
        } else {
          ctx.ui.notify("Not in a report branch.", "info");
          return;
        }
      }

      const summaryChoice = await ctx.ui.select(
        "Summarize report branch?",
        ["No summary", "Summarize"],
      );

      if (summaryChoice === undefined) {
        ctx.ui.notify("Cancelled. Still on report branch.", "info");
        return;
      }

      const originId = reportOriginId;
      const wantsSummary = summaryChoice === "Summarize";

      try {
        const result = await ctx.navigateTree(originId!, {
          summarize: wantsSummary,
        });

        if (result.cancelled) {
          ctx.ui.notify(
            "Navigation cancelled. Use /end-report to try again.",
            "info",
          );
          return;
        }

        setReportWidget(ctx, false);
        reportOriginId = undefined;
        pi.appendEntry(REPORT_STATE_TYPE, { active: false });

        ctx.ui.notify("Returned to main branch.", "info");
      } catch (error) {
        ctx.ui.notify(
          `Failed to return: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
      }
    },
  });
}
