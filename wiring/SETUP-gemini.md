# Gemini CLI setup — llm-wiki (DEPRECATED)

> **Gemini CLI is deprecated.** Google transitioned it to
> [Antigravity CLI](https://antigravity.google/blog/introducing-google-antigravity-cli);
> since 2026-06-18 it no longer serves consumer accounts (Google AI Pro/Ultra
> and free tiers). It keeps working only for Gemini Code Assist
> Standard/Enterprise licenses and paid API keys. **New setups should use
> `SETUP-antigravity.md`** — Antigravity retains Agent Skills and Hooks, and
> `agy plugin import gemini` migrates an existing MCP config.
> Migration guide: <https://antigravity.google/docs/cli/gcli-migration>.
> The instructions below apply only where Gemini CLI still runs (enterprise).

Skills + MCP verified 2026-07-09. Hooks: not supported (see below).

## Skills
Gemini auto-discovers Agent Skills from `.agents/skills/` (or `~/.agents/skills/`).

## Instructions
Gemini reads `GEMINI.md` by default; this repo no longer ships one (Antigravity,
its successor, reads `AGENTS.md` natively). Set `context.fileName` in settings to
include `AGENTS.md`, or create your own one-line `GEMINI.md` containing `@AGENTS.md`.

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

## Hooks — not supported
Gemini CLI has no hook system compatible with this plugin's scripts: no
PostToolUse/Stop events with the Claude-style stdin payload, and Gemini's
native write tools are `write_file`/`replace`, which the `Write|Edit` matcher
in `wiki-notify.sh` would never see. The session change manifest therefore
cannot be populated on Gemini.

Practical consequence: run the wiki-capture skill manually at the end of a work
session (the skill works fine without a manifest — it reviews the conversation
instead), and run wiki-ingest when your inbox piles up. If Gemini ships a
compatible hook system later, an adapter can shell out to the canonical scripts
under `hooks/scripts/` the way the OpenCode and Pi adapters do.
