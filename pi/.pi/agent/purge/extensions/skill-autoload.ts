/**
 * Skill Autoload Extension
 *
 * Automatically injects full skill content into the system prompt when
 * keywords from the user's prompt match a skill's `autoload-keywords`
 * metadata field.
 *
 * Add to any SKILL.md frontmatter:
 *   metadata:
 *     autoload-keywords: worktree, git wta, bare repo
 *
 * Keywords are matched case-insensitively against the user's prompt.
 * Word boundary matching is used for short keywords (<=4 chars) to avoid
 * false positives (e.g. "task" won't match "multitasking").
 */
import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface SkillEntry {
	name: string;
	keywords: string[];
	/** Regex patterns compiled from keywords */
	patterns: RegExp[];
	skillPath: string;
	content: string | null;
}

function parseAutoloadKeywords(content: string): string[] {
	// Extract frontmatter
	const match = content.match(/^---\n([\s\S]*?)\n---/);
	if (!match) return [];

	const frontmatter = match[1];
	// Look for autoload-keywords in metadata
	const kwMatch = frontmatter.match(/autoload-keywords:\s*(.+)/);
	if (!kwMatch) return [];

	return kwMatch[1]
		.split(",")
		.map((k) => k.trim())
		.filter(Boolean);
}

function buildPattern(keyword: string): RegExp {
	const escaped = keyword.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	// Short keywords get word boundary matching to avoid false positives
	if (keyword.length <= 4) {
		return new RegExp(`\\b${escaped}\\b`, "i");
	}
	return new RegExp(escaped, "i");
}

function findSkillFiles(dir: string): string[] {
	const results: string[] = [];
	if (!fs.existsSync(dir)) return results;

	const entries = fs.readdirSync(dir, { withFileTypes: true });
	for (const entry of entries) {
		const fullPath = path.join(dir, entry.name);
		if (entry.isFile() && entry.name.endsWith(".md")) {
			results.push(fullPath);
		} else if (entry.isDirectory()) {
			const skillMd = path.join(fullPath, "SKILL.md");
			if (fs.existsSync(skillMd)) {
				results.push(skillMd);
			}
		}
	}
	return results;
}

export default function (pi: ExtensionAPI) {
	const skills: SkillEntry[] = [];

	pi.on("session_start", async (_event, ctx) => {
		skills.length = 0;

		// Scan skill directories
		const skillDirs = [
			path.join(process.env.HOME || "~", ".pi", "agent", "skills"),
			path.join(ctx.cwd, ".pi", "skills"),
		];

		const seen = new Set<string>();

		for (const dir of skillDirs) {
			for (const filePath of findSkillFiles(dir)) {
				if (seen.has(filePath)) continue;
				seen.add(filePath);

				try {
					const content = fs.readFileSync(filePath, "utf-8");
					const keywords = parseAutoloadKeywords(content);
					if (keywords.length === 0) continue;

					// Extract name from frontmatter
					const nameMatch = content.match(/^---\n[\s\S]*?name:\s*(.+?)[\s\n]/);
					const name = nameMatch ? nameMatch[1].trim() : path.basename(path.dirname(filePath));

					skills.push({
						name,
						keywords,
						patterns: keywords.map(buildPattern),
						skillPath: filePath,
						content, // Pre-load content since we already read it
					});
				} catch {
					// Skip unreadable files
				}
			}
		}

		// Skills loaded silently — no status bar clutter
	});

	pi.on("before_agent_start", async (event) => {
		if (skills.length === 0) return;

		const prompt = event.prompt ?? "";
		const matched: SkillEntry[] = [];

		for (const skill of skills) {
			const hit = skill.patterns.some((p) => p.test(prompt));
			if (hit) {
				matched.push(skill);
			}
		}

		if (matched.length === 0) return;

		// Check if skills are already in the system prompt (from a previous injection
		// or because the LLM read them). We inject into system prompt which is rebuilt
		// each turn, so we always need to re-inject.
		let extra = "";
		for (const skill of matched) {
			if (!skill.content) {
				try {
					skill.content = fs.readFileSync(skill.skillPath, "utf-8");
				} catch {
					continue;
				}
			}

			// Strip frontmatter for injection (the system prompt already has the summary)
			const body = skill.content.replace(/^---\n[\s\S]*?\n---\n*/, "").trim();

			extra += `\n\n## Auto-loaded Skill: ${skill.name}\n\n${body}`;
		}

		if (extra) {
			return {
				systemPrompt: event.systemPrompt + extra,
			};
		}
	});
}
