// .pi/extensions/wiki-extension.ts — best-effort port of llm-wiki hooks.
import { spawn } from "node:child_process";
const ROOT = "/ABS/PATH/TO/llm-wiki";
const run = (script: string, payload: unknown) => {
  const p = spawn("bash", [`${ROOT}/hooks/scripts/${script}`], { stdio: ["pipe", "inherit", "inherit"] });
  p.stdin.end(JSON.stringify(payload));
};
export default (pi: any) => {
  pi.on("tool_result", (e: any) => {
    const name = e?.tool?.name ?? e?.name;
    const file = e?.tool?.arguments?.file_path ?? e?.arguments?.file_path;
    run("wiki-notify.sh", { tool_name: name, tool_input: { file_path: file }, session_id: e.sessionId });
    run("wiki-inbox-nudge.sh", { session_id: e.sessionId });
  });
  pi.on("session_shutdown", (e: any) => run("wiki-stop.sh", { session_id: e.sessionId }));
};
