# Codex CLI setup — llm-wiki

Verified: 2026-07-09.

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
