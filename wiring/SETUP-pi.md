# Pi setup — llm-wiki

Verified: 2026-07-09 (github.com/badlogic/pi-mono).

## Skills
Pi auto-discovers Agent Skills from `.agents/skills/` (project, up to git root) and
`~/.agents/skills/` (global). Pi does not require the skill `name` to match its dir.

## Instructions
Pi reads `AGENTS.md` natively (and `CLAUDE.md` as an alias). No shim needed.

## I/O — no MCP
Pi has no MCP by design. Install the Obsidian CLI so the skills use the CLI tier
(preferred), otherwise they fall back to file tools:
```bash
# install the `obsidian` CLI per its docs; the skills probe for it automatically
```
No MCP config file exists for Pi.

## Hooks — optional, best-effort
Copy `wiring/pi/wiki-extension.ts` to `.pi/extensions/wiki-extension.ts` and replace
the `ROOT` placeholder (`/ABS/PATH/TO/llm-wiki`) with this repo's absolute path. Field
names follow Pi's event payloads (verify against docs/extensions.md); this is
best-effort.
