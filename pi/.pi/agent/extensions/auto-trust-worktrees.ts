/**
 * Auto-trust worktree projects.
 *
 * Trusts any project whose cwd lives under one of the worktree roots listed in
 * the $G_FOLDER_ALIASES env var (format: "alias:/path,alias:/path,..."). This
 * way every new git worktree created under those roots is trusted automatically
 * without having to add each one to ~/.pi/agent/trust.json.
 */

import { realpathSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";
import type { ExtensionAPI, ProjectTrustEventResult } from "@earendil-works/pi-coding-agent";

function parseRoots(): string[] {
	const raw = process.env.G_FOLDER_ALIASES ?? "";
	return raw
		.split(",")
		.map((entry) => entry.slice(entry.indexOf(":") + 1).trim())
		.filter((path) => path.length > 0)
		.map((path) => {
			try {
				return realpathSync(resolve(path));
			} catch {
				return resolve(path);
			}
		});
}

function isInside(root: string, target: string): boolean {
	const rel = relative(root, target);
	return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

export default function (pi: ExtensionAPI) {
	const roots = parseRoots();

	pi.on("project_trust", async (event): Promise<ProjectTrustEventResult> => {
		let cwd: string;
		try {
			cwd = realpathSync(resolve(event.cwd));
		} catch {
			cwd = resolve(event.cwd);
		}

		if (roots.some((root) => isInside(root, cwd))) {
			return { trusted: "yes" };
		}
		return { trusted: "undecided" };
	});
}
