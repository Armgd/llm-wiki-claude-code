// .opencode/plugins/wiki-plugin.js — port of llm-wiki hooks for OpenCode.
// Verified against opencode 1.17.18 (plugin Hooks API).
import { spawn } from "node:child_process";
const ROOT = "/ABS/PATH/TO/llm-wiki";
const TOOL_NAMES = { write: "Write", edit: "Edit" };
const run = (script, payload) => {
  const p = spawn("bash", [`${ROOT}/hooks/scripts/${script}`], { stdio: ["pipe", "inherit", "inherit"] });
  p.stdin.end(JSON.stringify(payload));
};
export const WikiPlugin = async () => ({
  "tool.execute.after": async (input, output) => {
    const tool = TOOL_NAMES[input.tool];
    const file = input.args?.filePath ?? input.args?.file_path;
    if (tool && file) {
      run("wiki-notify.sh", { tool_name: tool, tool_input: { file_path: file }, session_id: input.sessionID });
    }
    run("wiki-inbox-nudge.sh", { session_id: input.sessionID });
  },
  event: async ({ event }) => {
    if (event.type === "session.idle") {
      run("wiki-stop.sh", { session_id: event.properties?.sessionID });
    }
  },
});
