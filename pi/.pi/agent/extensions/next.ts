/**
 * /next - Identify and execute the next step from plan.md using Haiku.
 * /next dry - Show what would be executed.
 * /next N - Execute step N specifically.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { BorderedLoader } from "@mariozechner/pi-coding-agent";
import { complete, type Model, type Api } from "@mariozechner/pi-ai";
import { promises as fs } from "node:fs";
import path from "node:path";

const HAIKU_ID = "claude-haiku-4-5";

const SYSTEM_PROMPT = `Given a plan, return the next actionable step as JSON: {"step": 3, "title": "..."}
If a specific step is requested, return that step. If none remain: {"step": null}`;

async function pickModel(ctx: { model: Model<Api>; modelRegistry: any }): Promise<Model<Api>> {
  const haiku = ctx.modelRegistry.find("anthropic", HAIKU_ID);
  if (haiku && (await ctx.modelRegistry.getApiKey(haiku))) return haiku;
  return ctx.model;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("next", {
    description: "Execute the next step from plan.md",
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      const isDry = trimmed === "dry";
      const specificStep = !isDry && trimmed ? parseInt(trimmed, 10) : NaN;

      const planPath = path.join(ctx.cwd, "plan.md");
      let content: string;
      try { content = await fs.readFile(planPath, "utf8"); } catch {
        ctx.ui.notify("No plan.md found", "error"); return;
      }
      if (!content.trim()) { ctx.ui.notify("plan.md is empty", "error"); return; }
      if (!ctx.model) { ctx.ui.notify("No model selected", "error"); return; }

      const model = await pickModel(ctx);
      const prompt = !isNaN(specificStep)
        ? `Find step ${specificStep}:\n\n${content}`
        : `Next step:\n\n${content}`;

      const result = await ctx.ui.custom<{ step: number; title: string } | null>((tui, theme, _kb, done) => {
        const loader = new BorderedLoader(tui, theme, `Identifying next step...`);
        loader.onAbort = () => done(null);

        (async () => {
          const apiKey = await ctx.modelRegistry.getApiKey(model);
          const res = await complete(model,
            { systemPrompt: SYSTEM_PROMPT, messages: [{ role: "user" as const, content: [{ type: "text" as const, text: prompt }], timestamp: Date.now() }] },
            { apiKey, signal: loader.signal });
          if (res.stopReason === "aborted") return done(null);
          const text = res.content.filter((c: any) => c.type === "text").map((c: any) => c.text).join("");
          const match = text.match(/\{[\s\S]*?\}/);
          if (!match) return done(null);
          const parsed = JSON.parse(match[0]);
          done(parsed.step != null ? parsed : null);
        })().catch(() => done(null));

        return loader;
      });

      if (!result) { ctx.ui.notify("No actionable step found", "info"); return; }

      if (isDry) {
        ctx.ui.notify(`Step ${result.step}: ${result.title}`, "info");
        return;
      }

      ctx.ui.notify(`Step ${result.step}: ${result.title}`, "info");
      pi.sendUserMessage(`@plan.md step ${result.step} go`);
    },
  });
}
