// .opencode/plugins/wiki-plugin.js — best-effort port of llm-wiki hooks.
// Verify OpenCode's plugin event API (tool.execute.after / session.*) against current docs.
import { spawn } from "node:child_process";
const ROOT = "/ABS/PATH/TO/llm-wiki";
const run = (script, payload) => {
  const p = spawn("bash", [`${ROOT}/hooks/scripts/${script}`], { stdio: ["pipe", "inherit", "inherit"] });
  p.stdin.end(JSON.stringify(payload));
};
export default (pi) => {
  pi.on?.("tool.execute.after", (e) => {
    const name = e.tool; const file = e?.args?.file_path ?? e?.args?.path;
    run("wiki-notify.sh", { tool_name: name, tool_input: { file_path: file }, session_id: e.sessionID });
    run("wiki-inbox-nudge.sh", { session_id: e.sessionID });
  });
  pi.on?.("session.idle", (e) => run("wiki-stop.sh", { session_id: e.sessionID }));
};
