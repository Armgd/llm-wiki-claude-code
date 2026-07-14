# Codex CLI setup — llm-wiki

Skills + MCP verified 2026-07-09. Hooks: not supported (see below).

## Skills
Codex auto-discovers Agent Skills from `.agents/skills/`. Clone/symlink this repo's
`.agents/skills/` into your project (or `~/.agents/skills/` for global). No further step.

## MCP (Obsidian) — optional
Codex `config.toml` has no `${VAR}` interpolation; put the absolute vault path in `args`:
```toml
[mcp_servers.obsidian]
command = "npx"
args = ["-y", "@bitbonsai/mcpvault@latest", "/absolute/path/to/your/vault"]
```
Without MCP the skills fall back to the `obsidian` CLI or file tools.

## Hooks — not supported
Codex has no hook system compatible with this plugin's scripts: there is no
PostToolUse/Stop equivalent that feeds `tool_name` / `tool_input.file_path` /
`session_id` on stdin, and Codex's write tool is `apply_patch`, which the
`Write|Edit` matcher in `wiki-notify.sh` would never see. The session change
manifest therefore cannot be populated on Codex.

Practical consequence: run the wiki-capture skill manually at the end of a work
session (the skill works fine without a manifest — it reviews the conversation
instead), and run wiki-ingest when your inbox piles up. If Codex ships a
compatible hook system later, an adapter can shell out to the canonical scripts
under `hooks/scripts/` the way the OpenCode and Pi adapters do.
