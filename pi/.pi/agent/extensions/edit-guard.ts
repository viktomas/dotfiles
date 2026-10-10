/**
 * Edit guard
 *
 * 1. Blocks `edit`/`write` calls whose arguments carry the fingerprint of the
 *    Anthropic strict-tool encoding bug: a C0 control character, or a literal
 *    `\uXXXX` in a prose/data file, that the target file does not already
 *    contain. Full context: ~/.pi/agent/ANTHROPIC_EDIT_BUG.md
 * 2. Blocks rewriting files with `sed -i`, `perl -i` or a python/node
 *    read-replace-write script (a separate model habit, same doc).
 *
 * Correctly encoded edits are never blocked: pi decodes valid JSON escapes
 * before this runs, so a good edit contains `€`, not `\u20ac`.
 */

import { readFile } from "node:fs/promises";
import { extname, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DOC = "~/.pi/agent/ANTHROPIC_EDIT_BUG.md";

const ESC = /\\u[0-9a-fA-F]{4}/g;
const CTRL = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g;

/** Files where a literal `\uXXXX` is legitimate source text. */
const CODE_EXT = new Set([
  ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".jsonl", ".py", ".go",
  ".rs", ".rb", ".java", ".kt", ".swift", ".c", ".h", ".cpp", ".cs", ".lua",
  ".sh", ".fish", ".bash", ".zsh", ".sql", ".el", ".vim", ".yaml", ".yml", ".toml",
]);

const SED_I = /\b(sed\s+(-[a-zA-Z]+\s+)*-i|perl\s+-[a-zA-Z]*i)/;
const SPLICE =
  /\b(python3?|node)\b[\s\S]*(read_text|\.read\(\)|readFileSync)[\s\S]*(write_text|\.write\(|writeFileSync)/;

function show(c: string): string {
  return c.startsWith("\\") ? c : "U+" + c.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0");
}

/** Pure check, exported for testing. Returns the offending sequences. */
export function findMangled(texts: string[], path: string, fileContent: string): string[] {
  const joined = texts.join("\n");
  const found = new Set<string>(joined.match(CTRL) ?? []);
  if (!CODE_EXT.has(extname(path).toLowerCase())) {
    for (const m of joined.match(ESC) ?? []) found.add(m);
  }
  return [...found].filter((m) => !fileContent.includes(m)).map(show);
}

export function isFileRewrite(cmd: string): boolean {
  // Scratch files under /tmp are fine unless the command also touches a real tree.
  if (/\/tmp\//.test(cmd) && !/(workspace|\.dotfiles|\.pi)\//.test(cmd)) return false;
  return SED_I.test(cmd) || SPLICE.test(cmd);
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const input = (event.input ?? {}) as any;

    if (event.toolName === "edit" || event.toolName === "write") {
      const path = String(input.path ?? "");
      const texts: string[] =
        event.toolName === "write"
          ? [String(input.content ?? "")]
          : (Array.isArray(input.edits) ? input.edits : []).flatMap((e: any) => [
              String(e?.oldText ?? ""),
              String(e?.newText ?? ""),
            ]);
      let file = "";
      try {
        file = await readFile(resolve(ctx.cwd, path.replace(/^@/, "")), "utf8");
      } catch {}
      const bad = findMangled(texts, path, file);
      if (bad.length) {
        return {
          block: true,
          reason:
            `edit-guard: blocked. Your ${event.toolName} arguments contain ${bad.join(", ")}, which ${path} does not contain. ` +
            `This is a known tool-call encoding bug, not text you meant to write: when Claude encodes a non-ASCII character ` +
            `(— – € § × …) as a JSON \\uXXXX escape inside a tool call, the escape can get mangled into a literal "\\u2014", ` +
            `a control character such as \\b or \\f followed by hex digits, or a newline followed by a letter (€ → "\\ne"). ` +
            `In oldText it makes the match fail; in newText it writes garbage to disk. ` +
            `Re-issue the same call with every non-ASCII character typed as the character itself, and check oldText for ` +
            `the same corruption. Also check for "" where a dash belongs, and newline+letter where a symbol belongs. ` +
            `If the file really needs that escape text, read the file first. Full explanation: ${DOC}`,
        };
      }
      return;
    }

    if (event.toolName === "bash" && isFileRewrite(String(input.command ?? ""))) {
      return {
        block: true,
        reason:
          `edit-guard: blocked. This rewrites files with sed -i / perl -i / a python|node read-replace-write script. ` +
          `Use the edit tool: put several changes to one file in one call as multiple edits[] entries. If oldText fails ` +
          `to match, read the region and retry with what is actually there. Don't switch to scripting, because a failed match ` +
          `usually means the oldText was mangled (see ${DOC}). For a genuinely mechanical change across many files, ask ` +
          `the user first.`,
      };
    }
  });
}
