import { type ExtensionAPI, isToolCallEventType } from "@earendil-works/pi-coding-agent";

const WEB_SEARCH_TIMEOUT = 300;

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (isToolCallEventType("bash", event) && event.input.command?.includes("search.mjs")) {
      if ((event.input.timeout ?? 0) < WEB_SEARCH_TIMEOUT) {
        event.input.timeout = WEB_SEARCH_TIMEOUT;
      }
    }
  });
}
