# llm-wiki

> An LLM-maintained wiki layer for your Obsidian vault. Captures session knowledge, ingests external sources, queries the wiki, and keeps it healthy — all via Claude Code slash commands.

Packaged as a Claude Code plugin. Bundles the [`mcpvault`](https://github.com/bitbonsai/mcpvault) MCP server for Obsidian access.

## What you get

Five slash commands (each is a Claude Code skill):

- **`/llm-wiki:wiki-capture`** — at the end of a session, file decisions, findings, and state into your vault as a session log. Promote patterns to standalone knowledge pages.
- **`/llm-wiki:wiki-ingest <path>`** — turn an inbox article, PDF, or meeting note into a source summary cross-referenced with existing knowledge.
- **`/llm-wiki:wiki-query <question>`** — ask the wiki a question. Get a synthesized answer with `[[wikilinks]]` as citations.
- **`/llm-wiki:wiki-lint`** — health check: orphans, broken links, stale TODOs, knowledge gaps. Optional `--fix` for safe repairs.
- **`/llm-wiki:wiki-configure`** — one-time interactive setup: maps your vault's folders to wiki roles, writes the schema, and tells you how to enable the MCP server.

Three hooks (automatic):
- Change manifest on every `Write`/`Edit` (drives session capture)
- Session-end reminder to run `/wiki-capture` if noteworthy work was done
- Inbox nudge when unprocessed items pile up (configurable threshold in the schema)

## Requirements

- [Claude Code](https://claude.com/claude-code)
- An Obsidian vault (PARA-shape, names are user-defined)
- Node.js 18+ (for the bundled `mcpvault` MCP server — runs via `npx`)
- `bash`, `jq` (for hooks)

## Install

### 1. Install the plugin

From this repo's marketplace entry (adjust to your distribution method):

```
/plugin install llm-wiki
```

Or from a local clone during development:

```
/plugin install ./path/to/llm-wiki
```

### 2. Configure your vault

Open Claude Code in any directory and run:

```
/llm-wiki:wiki-configure
```

This walks you through:
- Locating your Obsidian vault
- Mapping folders to wiki roles (`inbox`, `projects`, `resources`, `system`, optional `areas`/`notes`)
- Choosing your project sub-structure convention
- Setting the inbox-nudge threshold and wiki-source identifier

It writes:
- `~/.config/llm-wiki/vault` — a one-line file with your vault's absolute path
- `{vault}/_System/wiki-schema.md` — the filled-in schema describing your vault's conventions
- `{vault}/_System/Templates/*.md` — Obsidian Templater files for session logs, knowledge pages, and source summaries (only created if missing)
- `{vault}/_System/wiki-log.md` — the append-only operation log (only created if missing)

### 3. Enable the Obsidian MCP server

The plugin bundles the `mcpvault` MCP server in `.claude-plugin/plugin.json`. It needs your vault path via the `OBSIDIAN_VAULT_PATH` environment variable.

Add this to your shell profile (`~/.zshrc`, `~/.bashrc`, or equivalent), then restart Claude Code:

```bash
export OBSIDIAN_VAULT_PATH="/absolute/path/to/your/vault"
```

Without this env var, the MCP server won't start — but the `/wiki-*` commands still work via file-based fallbacks (Glob, Read, Write, Grep).

### 4. Try it

- In a work session, run `/llm-wiki:wiki-capture` to file the session.
- Put an article in your inbox and run `/llm-wiki:wiki-ingest "00 - Inbox/<article>.md"` to summarize it.
- Ask `/llm-wiki:wiki-query "What do we know about X?"` for a synthesized answer.
- Run `/llm-wiki:wiki-lint` weekly for a health report.

## Reconfiguring

Re-run `/llm-wiki:wiki-configure` any time. It detects the existing configuration, shows a diff of proposed changes, and applies only what differs.

## Uninstall

```
/plugin remove llm-wiki
```

This removes the plugin, its hooks, and the MCP server registration. Your vault content (schema, logs, notes) is left untouched. If you want to remove the schema and wiki-log too:

```bash
rm ~/.config/llm-wiki/vault
rm {vault}/_System/wiki-schema.md
# Keep wiki-log.md and notes — they're your content.
```

## Repo layout

```
.claude-plugin/
  plugin.json             # manifest + bundled mcpvault MCP server
skills/
  wiki-capture/SKILL.md
  wiki-ingest/SKILL.md
  wiki-query/SKILL.md
  wiki-lint/SKILL.md
  wiki-configure/SKILL.md
hooks/
  hooks.json              # references scripts via ${CLAUDE_PLUGIN_ROOT}
  scripts/
    wiki-notify.sh
    wiki-stop.sh
    wiki-inbox-nudge.sh
references/
  setup.md                # shared bootstrap, read by each /wiki-* skill
vault-files/              # seed files copied into {vault}/_System/ by /wiki-configure
  wiki-schema.md.template
  wiki-log.md
  Templates/*.md
test-fixtures/vault/      # minimal PARA vault for manual e2e walkthroughs
docs/superpowers/         # design spec + implementation plan (history)
reference.md              # background and rationale
```

## Design

Two layers:

- **Schema** — `{vault}/_System/wiki-schema.md` describes your vault's folder conventions, page types, and operation workflows. This is the single source of truth for everything the skills need to know about your vault. Edit it to change behavior.
- **Skills** — thin adapters in `skills/wiki-*/SKILL.md`. Each skill runs a shared bootstrap (`references/setup.md`) to load the schema, then executes its command using Obsidian MCP and file tools.

All vault-specific values (paths, folder names, thresholds) live in the schema, not the plugin code. The only thing outside the schema is `~/.config/llm-wiki/vault`, which tells hooks where to find the vault.

Full design spec: `docs/superpowers/specs/2026-04-15-llm-wiki-distribution-design.md`.

## Development

### Testing

Walk through `/llm-wiki:wiki-configure` against `test-fixtures/vault/` for first-time-setup flow. For each wiki command, use the fixture vault as the target and verify the expected files appear.

Hook scripts can be syntax-checked with `bash -n hooks/scripts/*.sh`.

### Plugin structure validation

```bash
jq -e . .claude-plugin/plugin.json >/dev/null && echo "manifest valid"
jq -e . hooks/hooks.json >/dev/null && echo "hooks valid"
```

## License

MIT
