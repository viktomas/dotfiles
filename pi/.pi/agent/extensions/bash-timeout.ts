/**
 * Bash default timeout (global)
 *
 * Re-registers the built-in bash tool with a default timeout so a stalled
 * command can never hang a session forever. The tool schema is the single
 * source of truth: its `timeout` parameter says there IS a default, and the
 * wrapper enforces exactly that — no contradicting system-prompt notes.
 *
 * - Default: 600s. PI_BASH_DEFAULT_TIMEOUT overrides ("0", "off", "disabled",
 *   "false" disable the extension; malformed values fall back to 600 with a
 *   warning — a typo must not silently turn a watchdog off; values above
 *   pi's max are capped).
 * - An explicit `timeout` from the model is always respected as-is.
 * - Commands that actually invoke subagent.sh / duo-subagent.sh / wait-for.sh
 *   are exempt: those launchers enforce their own outer bounds (subagents:
 *   timeout -k 30, --timeout, --idle watchdogs; wait-for.sh: its own
 *   --timeout, default 300s), and a forgotten explicit timeout must not kill
 *   a 30-minute duo run or a pipeline wait at 10 minutes. The match requires
 *   command position (start of command or after a shell separator, with
 *   optional env-assignment / nohup/env/time/exec/then/do/!/{ prefixes and
 *   path prefix), after quoted strings and heredoc bodies are blanked —
 *   `sleep 999 # duo-subagent.sh`, `echo duo-subagent.sh` or `subagent.sh.bak`
 *   do NOT evade the default. Quoted path-like tokens ("$SKILL/wait-for.sh")
 *   are unwrapped first so the skill's documented invocation forms match.
 *   This is a watchdog against forgotten timeouts, not a security boundary:
 *   the model can always pass an explicit (huge) timeout, so a line that
 *   really invokes a launcher is wholly exempt by design.
 *
 * Replaces the built-in because registerTool() writes extension tools into
 * the definition registry after the base tools (agent-session.ts
 * _refreshToolRegistry), so a same-name registration wins. Everything except
 * the schema text and the default is delegated to a fresh built-in definition
 * (renderers, truncation, output accumulation, process-tree kill), executed
 * with the same shellPath / shellCommandPrefix settings the built-in uses.
 *
 * Limitations, accepted:
 * - Settings are read on the first command and cached; changing them later
 *   needs /reload.
 * - Only one extension can replace "bash": the FIRST one to register the name
 *   wins (runner.ts getAllRegisteredTools), so load order decides collisions.
 * - Subagent sessions (subagent.sh runs `pi -ne`) do not load this extension,
 *   but their whole run is wrapped in `timeout -k 30` anyway.
 * - `bash subagent.sh x` (launcher as interpreter argument) is not exempt —
 *   the skills invoke the script directly.
 *
 * Delete this file once pi upstream ships a default timeout + setting.
 */

import { createBashToolDefinition, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** pi's resolveTimeoutMs rejects anything above this (bash.ts MAX_TIMEOUT_MS / 1000). */
const MAX_TIMEOUT_SECONDS = 2_147_483;
const FALLBACK_DEFAULT = 600;
const OFF_VALUES = new Set(["0", "off", "disabled", "false"]);

const rawDefault = process.env.PI_BASH_DEFAULT_TIMEOUT?.trim();
const provided = rawDefault !== undefined && rawDefault !== "";
const wantedDefault = provided ? Number(rawDefault) : undefined;

const offSwitch = provided && OFF_VALUES.has(rawDefault!.toLowerCase());
const malformed = provided && !offSwitch && (!Number.isFinite(wantedDefault!) || wantedDefault! <= 0);
const DEFAULT_TIMEOUT = offSwitch
  ? undefined
  : malformed
    ? FALLBACK_DEFAULT
    : Math.min(wantedDefault ?? FALLBACK_DEFAULT, MAX_TIMEOUT_SECONDS);
const capped = !malformed && (wantedDefault ?? FALLBACK_DEFAULT) > MAX_TIMEOUT_SECONDS;

/**
 * Launcher scripts that enforce their own outer bounds; a default here would only destroy work.
 * Command position only: start of command or after a separator (`;`, `&`, `|`, newline, `(`,
 * backtick), then any number of env assignments or prefix words, then an optional path prefix
 * and a launcher name, which must end at a separator or whitespace (not `.bak` etc.).
 */
const EXTERNALLY_BOUNDED = new RegExp(
  String.raw`(^|[;&|\n(` + "`" + String.raw`])\s*` +
    String.raw`(?:(?:nohup|env|time|exec|command|builtin|nice|stdbuf|then|do|!|\{)\s+|timeout\s+\S+\s+|\w+=\S*\s+)*` +
    String.raw`(\S*/)?(?:(duo-)?subagent|wait-for)\.sh(?=[\s;&|)\n]|$)`,
);

/**
 * Normalize a command before matching:
 * 1. Blank heredoc bodies — a launcher name there is data.
 * 2. Unwrap quoted path-like tokens (starting with `~/`, `/`, `./` or `$`) — the
 *    skills document invocations like `"$SKILL/wait-for.sh" "…"`, and the
 *    quotes are shell syntax around a path, not data.
 * 3. Blank all remaining quoted strings — a launcher name inside them is data
 *    (an argument of echo/git commit -m/…), not a command. Unlike git-guard's
 *    scannable(), there is no exec-a-string exception — `bash -c 'subagent.sh …'`
 *    is an accepted miss, same as the interpreter-invocation trade-off above.
 */
function scannable(cmd: string): string {
  return cmd
    .replace(/<<-?\s*(['"]?)(\w+)\1[^\n]*\n[\s\S]*?\n\s*\2\s*(\n|$)/g, "<<HEREDOC\n")
    .replace(/(["'])([~$.\/][^"']*)\1/g, "$2")
    .replace(/'[^']*'/g, "''")
    .replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

/** Exempt: the command line actually invokes a bounded launcher. */
export function invokesBoundedLauncher(cmd: string): boolean {
  return EXTERNALLY_BOUNDED.test(scannable(cmd));
}

export default function (pi: ExtensionAPI) {
  // Load-time problems must not write to stderr while the TUI is drawing;
  // collect them and surface once per session through the UI.
  const warnings: string[] = [];
  if (malformed) {
    warnings.push(
      `bash-timeout: PI_BASH_DEFAULT_TIMEOUT="${rawDefault}" is not a positive number; using ${FALLBACK_DEFAULT}s.`,
    );
  }
  if (capped) {
    warnings.push(`bash-timeout: PI_BASH_DEFAULT_TIMEOUT capped at pi's maximum, ${MAX_TIMEOUT_SECONDS}s.`);
  }
  if (DEFAULT_TIMEOUT === undefined) return; // explicit off switch: silent no-op

  // Registration source: renderers, promptSnippet, outputSchema and the description
  // text are identical for every createBashToolDefinition() call — only the
  // execute-time options (shellPath, commandPrefix) differ, and those are read
  // lazily below (pi.getSettings() is not callable during extension load).
  const registration = createBashToolDefinition(process.cwd());

  // The definition that actually executes, honoring the user's shellPath /
  // shellCommandPrefix settings exactly like the built-in does. Built on the
  // first execute call, when reading settings is allowed; a settings change
  // afterwards needs /reload.
  let delegate: ReturnType<typeof createBashToolDefinition> | undefined;
  const getDelegate = () => {
    if (!delegate) {
      const s = pi.getSettings() as { shellPath?: string; shellCommandPrefix?: string };
      delegate = createBashToolDefinition(process.cwd(), {
        ...(s.shellPath ? { shellPath: s.shellPath } : {}),
        ...(s.shellCommandPrefix ? { commandPrefix: s.shellCommandPrefix } : {}),
      });
    }
    return delegate;
  };

  // Sentence in the built-in tool description that documents the old behavior.
  const OLD_TIMEOUT_SENTENCE = "Optionally provide a timeout in seconds.";
  const NEW_TIMEOUT_SENTENCE =
    `Unless you pass a longer timeout, the command is killed after ${DEFAULT_TIMEOUT}s ` +
    `(partial output is returned). Pass an explicit larger timeout for long-running commands. ` +
    `Commands invoking subagent.sh / duo-subagent.sh / wait-for.sh are exempt (they enforce their own bounds).`;
  let description: string;
  if (registration.description.includes(OLD_TIMEOUT_SENTENCE)) {
    description = registration.description.replace(OLD_TIMEOUT_SENTENCE, NEW_TIMEOUT_SENTENCE);
  } else {
    description = `${registration.description} ${NEW_TIMEOUT_SENTENCE}`;
    warnings.push(
      "bash-timeout: the built-in bash tool description changed upstream; " +
        "the default-timeout sentence was appended, please check for contradictions.",
    );
  }

  // Warnings must not go to stderr while the TUI is drawing; surface them
  // once per session through the UI instead. Registered last so every
  // warning above (including the description-change one) is included.
  if (warnings.length > 0) {
    pi.on("session_start", async (_event, ctx) => {
      for (const w of warnings) ctx.ui.notify(w, "info");
    });
  }

  // Copy the schema instead of mutating it: registration.parameters is the module-level
  // bashSchema shared with the built-in (and the PowerShell tool), so an
  // in-place edit would leak "Default 600s" into definitions that don't
  // enforce it and survive /reload. Object spread keeps TypeBox's symbol keys.
  const parameters = {
    ...registration.parameters,
    properties: {
      ...registration.parameters.properties,
      timeout: {
        ...registration.parameters.properties.timeout,
        description:
          `Timeout in seconds. Default ${DEFAULT_TIMEOUT}s; pass a larger value for ` +
          `long-running commands.`,
      },
    },
  };

  pi.registerTool({
    ...registration,
    description,
    parameters,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      // Forward everything the model sent (future params survive); only the
      // missing timeout is filled in.
      const timeout =
        params.timeout ?? (invokesBoundedLauncher(params.command) ? undefined : DEFAULT_TIMEOUT);
      return getDelegate().execute(toolCallId, { ...params, timeout }, signal, onUpdate, ctx);
    },
  });
}
