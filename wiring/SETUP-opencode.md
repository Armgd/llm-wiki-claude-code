# OpenCode setup — llm-wiki

Verified: 2026-07-13 against opencode 1.17.18 (skills discovery + plugin hooks tested end-to-end).

## Skills
OpenCode reads `.agents/skills/` and `.claude/skills/` directly. Point it at this repo's
`.agents/skills/`.

## I/O
Install the `obsidian` CLI so the skills use the CLI tier (preferred); otherwise
they fall back to file tools. No other wiring needed.

## Hooks — optional
Copy `wiring/opencode/wiki-plugin.js` to `.opencode/plugins/wiki-plugin.js` and replace
the `ROOT` placeholder (`/ABS/PATH/TO/llm-wiki`) with this repo's absolute path.
Tested on opencode 1.17.18: `tool.execute.after` feeds wiki-notify/wiki-inbox-nudge,
`session.idle` (event hook) triggers wiki-stop.
