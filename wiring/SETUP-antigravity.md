# Antigravity CLI (agy) setup — llm-wiki

Antigravity CLI is Google's successor to Gemini CLI (consumer Gemini CLI stopped
being served on 2026-06-18 — see `SETUP-gemini.md`). Written against the public
docs and community references as of 2026-07-14; not yet verified end-to-end
against a live install. Docs: <https://antigravity.google/docs/cli/overview>,
migration guide: <https://antigravity.google/docs/cli/gcli-migration>.

## Skills
Antigravity auto-discovers Agent Skills from the workspace's `.agents/skills/`
(this repo's layout works as-is) and globally from
`~/.gemini/antigravity-cli/skills/`. Clone/symlink this repo's `.agents/skills/`
into your project, or copy the five `wiki-*` dirs into the global path.
`agy inspect` lists the configuration files it loaded — use it to confirm the
skills and `AGENTS.md` were picked up.

## Instructions
Antigravity reads `AGENTS.md` natively. No shim needed.

## MCP (Obsidian) — optional
- Migrating from Gemini CLI: `agy plugin import gemini` carries your MCP server
  registrations over, including an existing `obsidian` entry.
- Fresh setup: use `/mcp` inside `agy` to register the server. Env-var
  interpolation is undocumented — pass the absolute vault path:
  `npx -y @bitbonsai/mcpvault@latest /absolute/path/to/your/vault`

Without MCP the skills fall back to the `obsidian` CLI or file tools.

## Hooks — best-effort adapter
Antigravity has a compatible hook system (`PreToolUse`, `PostToolUse`,
`PreInvocation`, `PostInvocation`, `Stop`) but a different stdin payload
(`toolCall.name` / `toolCall.args` instead of Claude's `tool_name` /
`tool_input`), so the canonical scripts need the translation shim in
`wiring/antigravity/wiki-hook-adapter.sh`.

Setup:
1. Merge `wiring/antigravity/wiki-hooks.json` into `~/.gemini/antigravity-cli/hooks.json`
   (global) or `<project>/.agents/hooks.json` (project), replacing
   `/ABS/PATH/TO/llm-wiki` with this repo's absolute path.
2. Verify the payload: the file-path field inside `toolCall.args` is not
   publicly documented. The adapter tries `TargetFile`, `AbsolutePath`,
   `file_path`, `path` and exits silently otherwise — log a raw payload from a
   throwaway hook and adjust if the change manifest stays empty.

Known gaps:
- `Stop` likely fires per turn (as on Claude Code); the canonical
  `wiki-stop.sh` already de-duplicates to one reminder per session.
- No `SessionEnd` equivalent, so per-session `/tmp/wiki-*` state is not cleaned
  up until reboot — harmless, the files are tiny and session-scoped.
- Hook stdout handling on PostToolUse/Stop is undocumented; the reminder text
  may or may not surface in the UI. The change manifest (which drives
  wiki-capture) works regardless of message delivery.
