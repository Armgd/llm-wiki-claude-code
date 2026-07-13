// .pi/extensions/wiki-extension.ts — port of llm-wiki hooks for Pi.
// Verified against pi-coding-agent 0.80.6 (docs/extensions.md).
import { spawn } from "node:child_process";
import { resolve } from "node:path";
const ROOT = "/ABS/PATH/TO/llm-wiki";
const TOOL_NAMES: Record<string, string> = { write: "Write", edit: "Edit" };
// Awaited inside handlers: pi ctx becomes stale once the handler returns.
const run = (script: string, payload: unknown): Promise<string> =>
  new Promise((done) => {
    const p = spawn("bash", [`${ROOT}/hooks/scripts/${script}`], { stdio: ["pipe", "pipe", "ignore"] });
    let out = "";
    p.stdout.on("data", (d) => (out += d));
    p.on("close", () => done(out.trim()));
    p.stdin.end(JSON.stringify(payload));
  });
export default function (pi: any) {
  pi.on("tool_result", async (event: any, ctx: any) => {
    const session_id = ctx.sessionManager.getSessionId();
    const tool = TOOL_NAMES[event.toolName];
    if (tool && event.input?.path) {
      await run("wiki-notify.sh", { tool_name: tool, tool_input: { file_path: resolve(event.input.path) }, session_id });
    }
    const nudge = await run("wiki-inbox-nudge.sh", { session_id });
    if (nudge) ctx.ui.notify(nudge, "info");
  });
  pi.on("session_shutdown", async (_event: any, ctx: any) => {
    const msg = await run("wiki-stop.sh", { session_id: ctx.sessionManager.getSessionId() });
    if (msg) ctx.ui.notify(msg, "info");
  });
}
