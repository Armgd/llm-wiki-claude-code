# Gemini CLI setup — llm-wiki

Verified: 2026-07-09.

## Skills
Gemini auto-discovers Agent Skills from `.agents/skills/` (or `~/.agents/skills/`).

## Instructions
Gemini reads `GEMINI.md` by default. This repo ships one that imports `AGENTS.md`.
Alternatively set `context.fileName` in settings to include `AGENTS.md`.

## MCP (Obsidian) — optional
`settings.json` supports `${VAR}`:
```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": ["-y", "@bitbonsai/mcpvault@latest", "${OBSIDIAN_VAULT_PATH}"]
    }
  }
}
```

## Hooks — optional
Merge `wiring/gemini/settings.hooks.json` into `settings.json` (replace
`/ABS/PATH/TO/llm-wiki` with this repo's absolute path). Confirm Gemini's
PostToolUse/Stop event names and stdin field names against the current repo before
relying on this.
