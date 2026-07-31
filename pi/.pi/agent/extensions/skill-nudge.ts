/**
 * Skill nudge
 *
 * Loads a skill automatically when it is clearly needed, from two directions:
 *
 * 1. `before_agent_start` — my prompt matches a rule's patterns → the skill body
 *    is injected as a message before the agent starts.
 * 2. `tool_call` — the agent is *about to* run a matching command and the skill
 *    is still not in context → the call is blocked and the skill body is
 *    returned as the block reason, so the model re-plans with the skill loaded.
 *
 * Both directions share the same `patterns` per rule. Each rule fires at most
 * once per session.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const SKILLS_DIR = join(homedir(), ".pi", "agent", "skills");

type Rule = {
	id: string;
	/** Matched against both the user prompt and the command the agent wants to run. */
	patterns: RegExp[];
	/** Extra patterns matched against the user prompt only (natural-language wording). */
	promptPatterns?: RegExp[];
	skill?: string;
};

/** Ordered: most specific rule first. */
const RULES: Rule[] = [
	{
		id: "gitlab-mr-comments",
		patterns: [
			/\bglab\s+mr\s+(note|comment)\b/i,
			/api\/v4\/[^"'\s]*\/(discussions|notes)\b/i,
			/\bglab\s+api\b[^\n]*\b(discussions|notes)\b/i,
			/\b(createDiffNote|createNote|discussionToggleResolve)\b/,
		],
		promptPatterns: [
			/\bmr\s+(comment|note|thread|discussion)s?\b/i,
			/\bmerge\s+request\s+(comment|note|thread|discussion)s?\b/i,
			/\b(comment|note|thread|discussion)s?\s+on\s+(the\s+)?mr\b/i,
			/\breview\s+comments?\b/i,
			/\bresolve\s+(the\s+)?thread/i,
			/\bunresolved\s+(thread|discussion)/i,
		],
	},
	{
		id: "gitlab-api",
		patterns: [/\bglab\b/i, /api\/v4\//i, /PRIVATE-TOKEN|GITLAB_TOKEN/i, /gitlab\.com\/api\b/i],
		promptPatterns: [
			/\bgitlab\s+api\b/i,
			/\b(create|update|close)\s+(?:a|an|the|this|that)?\s*(issue|epic)\b/i,
		],
	},
	{
		id: "report",
		patterns: [],
		promptPatterns: [/\breports?\b/i],
	},
	{
		id: "git-worktree",
		patterns: [/\bgit\s+worktree\b/i, /\bgit\s+wt[au]\b/i],
			promptPatterns: [/\bworktree\b/i, /\b(create|make|start)\s+(?:a|an|the)?\s*(new\s+)?branch\b/i],
	},
];

function skillPath(rule: Rule): string {
	return rule.skill ?? join(SKILLS_DIR, rule.id, "SKILL.md");
}

/** Text the agent is about to run/write, for pattern matching. */
function intentText(toolName: string, input: Record<string, unknown>): string {
	if (toolName === "bash") return String(input.command ?? "");
	return "";
}

function matches(rule: Rule, text: string, includePromptPatterns: boolean): boolean {
	if (!text) return false;
	if (rule.patterns.some((re) => re.test(text))) return true;
	return includePromptPatterns ? (rule.promptPatterns ?? []).some((re) => re.test(text)) : false;
}

/** Serialized active context — used to detect a skill that is already loaded. */
function contextText(ctx: ExtensionContext): string {
	try {
		return ctx.sessionManager
			.buildContextEntries()
			.map((entry) => JSON.stringify(entry))
			.join("\n");
	} catch {
		return "";
	}
}

function skillBody(rule: Rule): string | undefined {
	const path = skillPath(rule);
	if (!existsSync(path)) return undefined;
	try {
		return [
			`[skill-nudge:${rule.id}] Follow the "${rule.id}" skill for this work.`,
			`Skill file: ${path}`,
			"",
			readFileSync(path, "utf8"),
		].join("\n");
	} catch {
		return undefined;
	}
}

export default function skillNudge(pi: ExtensionAPI) {
	const nudged = new Set<string>();

	pi.on("session_start", () => {
		nudged.clear();
	});

	/**
	 * Rules matching `text` whose skill is not in context yet. Rules already
	 * present in context are marked as nudged here; callers mark the ones they
	 * actually inject.
	 */
	function candidates(text: string, ctx: ExtensionContext, includePromptPatterns: boolean): Rule[] {
		const result: Rule[] = [];
		let context: string | undefined;

		for (const rule of RULES) {
			if (nudged.has(rule.id)) continue;
			if (!matches(rule, text, includePromptPatterns)) continue;
			if (!existsSync(skillPath(rule))) continue;

			// Already in context (used /skill:, read the file, or nudged earlier)?
			context ??= contextText(ctx);
			if (context.includes(skillPath(rule)) || context.includes(`skill-nudge:${rule.id}`)) {
				nudged.add(rule.id);
				continue;
			}

			result.push(rule);
		}

		return result;
	}

	// 1. My prompt mentions the topic -> preload the skill.
	pi.on("before_agent_start", async (event, ctx) => {
		const rules = candidates(event.prompt ?? "", ctx, true);
		if (rules.length === 0) return;

		const bodies = rules.map(skillBody).filter((body): body is string => Boolean(body));
		if (bodies.length === 0) return;
		for (const rule of rules) nudged.add(rule.id);

		ctx.ui.notify(`Preloaded skill(s): ${rules.map((r) => r.id).join(", ")}`, "info");

		return {
			message: {
				customType: "skill-nudge",
				content: bodies.join("\n\n---\n\n"),
				display: true,
			},
		};
	});

	// 2. The agent is about to do it anyway -> block and hand over the skill.
	pi.on("tool_call", async (event, ctx) => {
		const text = intentText(event.toolName, (event.input ?? {}) as Record<string, unknown>);
		const rule = candidates(text, ctx, false)[0];
		if (!rule) return;

		const body = skillBody(rule);
		if (!body) return;
		nudged.add(rule.id);

		ctx.ui.notify(`Injected skill "${rule.id}" before ${event.toolName} call`, "info");

		return {
			block: true,
			reason: `${body}\n\nNow retry, following the instructions above.`,
		};
	});
}
