# OpenCode setup — llm-wiki

Verified: 2026-07-09.

## Skills
OpenCode reads `.agents/skills/` and `.claude/skills/` directly. Point it at this repo's
`.agents/skills/`.

## MCP (Obsidian) — optional
`opencode.json` uses `{env:VAR}` and a command array:
```json
{
  "mcp": {
    "obsidian": {
      "type": "local",
      "command": ["npx", "-y", "@bitbonsai/mcpvault@latest", "{env:OBSIDIAN_VAULT_PATH}"],
      "enabled": true
    }
  }
}
```
