import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

function autoOnByClock(now = new Date()): boolean {
  const day = now.getDay(); // 0 = Sun, 6 = Sat
  return day >= 1 && day <= 5 && now.getHours() < 13;
}


export default function(pi: ExtensionAPI) {
  let override: boolean | undefined;

  function isEnabled() {
    return override ?? autoOnByClock();
  }

  function updateStatus(ctx: ExtensionContext) {
    ctx.ui.setStatus("fuck-off", isEnabled() ? "Fuck off" : undefined)
  }

  pi.on("session_start", async (event, ctx) => {
    updateStatus(ctx);
  });

  pi.registerCommand("fuckoff", {
    description: "Turn fuck off mode on or off",
    handler: async (args, ctx) => {
      override = !isEnabled()
      ctx.ui.notify(`Fuck off mode ${override ? "enabled" : "disabled"}`)
      updateStatus(ctx)
    }
  });

  pi.on("before_agent_start", async (event, ctx) => {
    updateStatus(ctx)
    if (!isEnabled()) return;
    return { systemPrompt: event.systemPrompt + "\n\nYou are in a fuck off mode, this is a mode designed to make the user write code again. You are generally not allowed to implement any code (bugfix/feature/tooling) unless it's obviously part of gdk setup. Tell the user to write the code himself. Suggest the changes in principle, not vberbatim copy-paste. If the user ask you to review his code, do it and suggest improvements, don't make the improvements" }
  });
}
