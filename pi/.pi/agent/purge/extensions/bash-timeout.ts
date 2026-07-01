import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

const DEFAULT_BASH_TIMEOUT = 30;

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (isToolCallEventType("bash", event)) {
      if (event.input.timeout === undefined) {
        event.input.timeout = DEFAULT_BASH_TIMEOUT;
      }
    }
  });
}
