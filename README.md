# llm-wiki

> An LLM-maintained wiki layer for your Obsidian vault. Captures session knowledge, ingests external sources, queries the wiki, and keeps it healthy — as a set of portable Agent Skills that run on Claude Code, Codex, Gemini CLI, OpenCode, and Pi.

The skills are agent-agnostic: they read the vault's schema, then talk to Obsidian through whichever I/O tier is available (CLI, MCP, or plain file tools) and drive the same five operations regardless of which agent is running them.

## Supported agents

| Agent | Skills | Obsidian I/O | Hooks |
|---|---|---|---|
| Claude Code | ✓ (`.agents/skills/` via `plugin.json`) | MCP (bundled `mcpvault` server) or CLI | ✓ native |
| Codex | ✓ (auto-discovered) | MCP (manual config) or CLI | ✓ config-based |
| Gemini CLI | ✓ (auto-discovered) | MCP (`${VAR}` supported) or CLI | ✓ config-based |
| OpenCode | ✓ (auto-discovered) | MCP (`{env:VAR}` supported) or CLI | best-effort |
| Pi | ✓ (auto-discovered) | CLI only (no MCP) | best-effort |

## Install

Per-agent setup lives in `wiring/`:

- Claude Code: `/plugin install ./path/to/llm-wiki` (or from a marketplace entry), then run `/llm-wiki:wiki-configure`.
- Codex: [`wiring/SETUP-codex.md`](wiring/SETUP-codex.md)
- Gemini CLI: [`wiring/SETUP-gemini.md`](wiring/SETUP-gemini.md)
- OpenCode: [`wiring/SETUP-opencode.md`](wiring/SETUP-opencode.md)
- Pi: [`wiring/SETUP-pi.md`](wiring/SETUP-pi.md)

Every agent needs the vault configured once — run the `wiki-configure` skill (Claude: `/llm-wiki:wiki-configure`) against your vault. It maps folders to wiki roles, writes `{vault}/_System/wiki-schema.md`, and reports which I/O tier it detected.

## The five operations

- **wiki-capture** — at the end of a session, file decisions, findings, and state into your vault as a session log. Promote patterns to standalone knowledge pages.
- **wiki-ingest** — turn an inbox article, PDF, or meeting note into a source summary cross-referenced with existing knowledge.
- **wiki-query** — ask the wiki a question. Get a synthesized answer with `[[wikilinks]]` as citations.
- **wiki-lint** — health check: orphans, broken links, stale TODOs, knowledge gaps. Optional `--fix` for safe repairs.
- **wiki-configure** — one-time interactive setup: maps your vault's folders to wiki roles, writes the schema, and tells you how to enable Obsidian access.

On Claude Code these are slash commands (`/llm-wiki:wiki-*`); on Codex/Gemini/OpenCode/Pi they're auto-discovered Agent Skills invoked by name or natural-language trigger.

Three hooks (Claude native, Codex/Gemini config-based, OpenCode/Pi best-effort):
- Change manifest on every `Write`/`Edit` (drives session capture)
- Session-end reminder to run wiki-capture if noteworthy work was done
- Inbox nudge when unprocessed items pile up (configurable threshold in the schema)

## Portability: the 3-tier I/O fallback

Every skill sources `shared/scripts/wiki-io.sh`, which probes for Obsidian access in order and exports `WIKI_IO_BACKEND`:

1. **CLI** — the `obsidian` CLI, if installed. Works everywhere, including Pi (no MCP support).
2. **MCP** — the `obsidian` MCP server (bundled for Claude via `mcpvault`; manual config for Codex/Gemini/OpenCode), when the CLI isn't available.
3. **File tools** — plain Read/Write/Glob/Grep, when neither CLI nor MCP is available.

Because no skill body hardcodes a specific I/O mechanism, the same `.agents/skills/` directory runs unmodified on any agent that supports the Agent Skills convention — the skill just adapts to whichever tier it finds at runtime.

## Repo layout

```
.claude-plugin/
  plugin.json               # Claude manifest — skills path + bundled mcpvault MCP server
.agents/skills/              # canonical skill bodies, auto-discovered by Codex/Gemini/OpenCode/Pi
  wiki-capture/SKILL.md
  wiki-ingest/SKILL.md
  wiki-query/SKILL.md
  wiki-lint/SKILL.md
  wiki-configure/
    SKILL.md
    vault-files/            # seed files copied into {vault}/_System/ by wiki-configure
      wiki-schema.md.template
      wiki-log.md
      AGENTS.md.template
      Templates/*.md
shared/                      # canonical source of shared skill payload (kept in sync into each skill dir)
  references/
    setup.md                # shared bootstrap, read by each skill
    cli-patterns.md          # obsidian CLI usage patterns
  scripts/
    wiki-io.sh               # 3-tier I/O probe + CLI wrappers
hooks/
  hooks.json                # Claude hook config (${CLAUDE_PLUGIN_ROOT})
  scripts/
    wiki-notify.sh
    wiki-stop.sh
    wiki-inbox-nudge.sh
wiring/                      # per-agent setup docs + config/plugin files
  SETUP-codex.md / SETUP-gemini.md / SETUP-opencode.md / SETUP-pi.md
  codex/hooks.json
  gemini/settings.hooks.json
  opencode/wiki-plugin.js
  pi/wiki-extension.ts
AGENTS.md                    # instructions all agents read (Codex/OpenCode/Pi natively)
CLAUDE.md / GEMINI.md        # shims that import AGENTS.md
scripts/
  sync-skills.sh             # copies shared/ into every .agents/skills/*/
  check.sh                   # aggregate validation (see Development)
test-fixtures/vault/         # minimal PARA vault for manual e2e walkthroughs
reference.md                 # background and rationale
```

## Design

Two layers:

- **Schema** — `{vault}/_System/wiki-schema.md` describes your vault's folder conventions, page types, and operation workflows. This is the single source of truth for everything the skills need to know about your vault. Edit it to change behavior.
- **Skills** — thin adapters in `.agents/skills/wiki-*/SKILL.md`. Each skill runs a shared bootstrap (`references/setup.md`, synced from `shared/`) to load the schema, then executes its command using the detected I/O tier.

All vault-specific values (paths, folder names, thresholds) live in the schema, not the skill code. The only thing outside the schema is `~/.config/llm-wiki/vault`, which tells hooks where to find the vault.

## Development

Skill bodies pull shared references/scripts from `shared/` — never edit the copies inside `.agents/skills/*/references` or `.agents/skills/*/scripts` directly. Edit `shared/` and resync:

```bash
scripts/sync-skills.sh          # sync shared/ into every skill
scripts/sync-skills.sh --check  # verify no drift (fails if a skill copy differs)
```

Run the aggregate check before committing:

```bash
bash scripts/check.sh
```

It validates plugin/hooks/wiring JSON, shell syntax, skill sync, the OpenCode plugin, and that no skill or shared file leaks the Claude-only `${CLAUDE_PLUGIN_ROOT}` token.

Walk through the `wiki-configure` skill against `test-fixtures/vault/` for first-time-setup flow. For each wiki command, use the fixture vault as the target and verify the expected files appear.

## Requirements

- `bash`, `jq` — required for hooks, and for the obsidian-CLI I/O tier (`wiki_cli_move` uses `jq` to JSON-encode paths safely).
- An Obsidian vault (PARA-shape, names are user-defined)
- Node.js 18+ if using the MCP tier (bundled `mcpvault` server runs via `npx`), and to run `scripts/check.sh` (it `node --check`s the OpenCode adapter)
- One of: Claude Code, Codex, Gemini CLI, OpenCode, or Pi

## License

MIT
