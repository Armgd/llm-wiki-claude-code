# Antigravity CLI (agy) setup — llm-wiki

Antigravity CLI is Google's successor to Gemini CLI (consumer Gemini CLI stopped
being served on 2026-06-18 — see `SETUP-gemini.md`). Skills discovery verified
2026-07-14 against agy 1.1.2 (hooks still unverified — see below). Docs:
<https://antigravity.google/docs/cli/overview>, migration guide:
<https://antigravity.google/docs/cli/gcli-migration>.

## Skills
Despite what the bundled `agy-customizations` docs claim, agy 1.1.2 does NOT
load workspace skills: `.agents/skills/` and an explicit `.agents/skills.json`
manifest are both ignored, trusted workspace or not (tested headless `-p`).
Only global discovery works — symlink the five skill dirs into
`~/.gemini/config/skills/`:

```sh
mkdir -p ~/.gemini/config/skills
for s in wiki-capture wiki-configure wiki-ingest wiki-lint wiki-query; do
  ln -sfn /ABS/PATH/TO/llm-wiki/.agents/skills/$s ~/.gemini/config/skills/$s
done
```

There is no `agy inspect` subcommand (despite earlier references). To confirm
discovery, run:
`agy -p "Without running any commands, list the Agent Skills available to you"`
— the five `wiki-*` names should appear alongside the built-in
`antigravity-guide`.

## Instructions
Antigravity reads `AGENTS.md` natively. No shim needed.

## I/O
Install the `obsidian` CLI so the skills use the CLI tier (preferred); otherwise
they fall back to file tools. No other wiring needed.

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
