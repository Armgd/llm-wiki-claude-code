# OpenCode setup — llm-wiki

Verified: 2026-07-13 against opencode 1.17.18 (skills discovery + plugin hooks tested end-to-end).

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

## Hooks — optional
Copy `wiring/opencode/wiki-plugin.js` to `.opencode/plugins/wiki-plugin.js` and replace
the `ROOT` placeholder (`/ABS/PATH/TO/llm-wiki`) with this repo's absolute path.
Tested on opencode 1.17.18: `tool.execute.after` feeds wiki-notify/wiki-inbox-nudge,
`session.idle` (event hook) triggers wiki-stop.
