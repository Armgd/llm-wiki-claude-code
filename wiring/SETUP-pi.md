# Pi setup — llm-wiki

Verified: 2026-07-13 against pi-coding-agent 0.80.6 (skills discovery + extension tested end-to-end).

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

## Hooks — optional
Copy `wiring/pi/wiki-extension.ts` to `.pi/extensions/wiki-extension.ts` and replace
the `ROOT` placeholder (`/ABS/PATH/TO/llm-wiki`) with this repo's absolute path.
Tested on pi 0.80.6: `tool_result` feeds wiki-notify/wiki-inbox-nudge, `session_shutdown`
triggers wiki-stop. Note: project extensions load only once the project is trusted
(`/trust`, or `--approve` in non-interactive mode).
