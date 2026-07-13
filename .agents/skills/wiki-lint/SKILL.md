---
name: wiki-lint
description: "Use this skill to health-check an Obsidian-based LLM wiki \u2014 detect orphans, broken wikilinks, stale session-log TODOs, unprocessed inbox items, and knowledge gaps. Triggers when the user runs the wiki-lint skill (Claude: `/llm-wiki:wiki-lint`), asks to \"audit my wiki\", \"run a wiki health check\", or similar maintenance requests. Supports an optional --fix flag for safe repairs."
argument-hint: "[--fix]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, mcp__obsidian__search_notes, mcp__obsidian__read_note, mcp__obsidian__get_vault_stats, mcp__obsidian__list_directory, mcp__obsidian__get_frontmatter, mcp__obsidian__get_notes_info
---

# wiki-lint skill (Claude: `/llm-wiki:wiki-lint`)

Health-check the user's Obsidian wiki and report (optionally repair) issues.

## Bootstrap (required)

**Resolve the skill directory first.** Set `SKILL_DIR` to the absolute path of this
skill's directory. In Claude Code, use `${CLAUDE_SKILL_DIR}` (your host substitutes it).
On Codex, Gemini, OpenCode, or Pi, substitute the absolute skill path your host reported
when it loaded this skill. A Bash step's working directory is the user's project, not the
skill dir, so every bundled-file reference below uses `$SKILL_DIR` — never a bare relative path.

Read `$SKILL_DIR/references/setup.md` in full and follow it before proceeding. Do not proceed until bootstrap succeeds.

## Arguments

Optional `--fix` flag to auto-apply safe repairs (add cross-references, link orphans to relevant MOCs).

## Workflow

1. **Bootstrap** — run the setup bootstrap above. This gives you `VAULT_PATH`, `WIKI_SOURCE`, `folders.*`, `paths.*`, and `io.*`.

   **Probe I/O backend** — run via Bash:
   ```bash
   SKILL_DIR="${CLAUDE_SKILL_DIR}"   # Claude fills this; other hosts: set to the abs skill dir
   source "$SKILL_DIR/scripts/wiki-io.sh"
   wiki_io_probe "${VAULT_PATH}"
   echo "Backend: $WIKI_IO_BACKEND"
   ```
   - If `WIKI_IO_BACKEND` is `"cli"` → use CLI for all read/search/write operations. Consult `$SKILL_DIR/references/cli-patterns.md` for syntax.
   - If `WIKI_IO_BACKEND` is `"mcp"` → if this agent exposes Obsidian MCP tools
     (Claude/Gemini/OpenCode name them `mcp__obsidian__*`; other agents may not have
     them at all), probe `mcp__obsidian__list_directory` on the vault root and use MCP
     if it responds. Otherwise use file tools (Read/Write/Edit/Grep/Glob). Agents
     without MCP (e.g. Pi) always land on the CLI or file-tool tier — this is expected.
   - Commit to one tier for the entire workflow.

2. **Inventory the wiki**:
   - **CLI**:
     ```bash
     obsidian tags counts
     obsidian search query="wiki-source:" limit=500
     ```
   - **MCP**: `mcp__obsidian__get_vault_stats` + `mcp__obsidian__list_directory` + `mcp__obsidian__search_notes`
   - **File tools**: `Glob '{VAULT_PATH}/**/*.md'` + Bash `wc -l`; `Grep "wiki-source:"` for wiki pages
   - Count pages by type: session-log, knowledge, source-summary

3. **Check index consistency** (only if `{paths.index}` is non-empty):
   - Read `{VAULT_PATH}/{paths.index}` and extract the content between `<!-- llm-wiki:index:start -->` and `<!-- llm-wiki:index:end -->`.
   - If markers are missing: report `Index markers missing — run wiki-capture (or --fix)` (Claude: `/llm-wiki:wiki-capture`) and skip the rest of this step.
   - Compare the set of `[[wikilinks]]` inside the block against the set of `knowledge` + `source-summary` pages found via frontmatter search:
     - **Missing entries**: pages that exist in the vault but are not listed in the index.
     - **Stale entries**: index entries that point to pages that no longer exist (renamed/deleted).
     - **Domain drift**: index groups a page under a domain that differs from the page's current `domain` frontmatter.
   - Report counts for each category.

4. **Check for orphans** (pages unreachable from index **and** with no inbound wikilinks):
   - Run the classic orphan check: for each wiki-generated page, Grep for inbound `[[wikilinks]]`.
   - If `{paths.index}` is set, a page counts as reachable if it's listed in the index managed block OR has any inbound wikilink. Orphans are pages with **neither**.
   - If `{paths.index}` is empty, fall back to the classic "no inbound wikilinks" definition.
   - Report: list of orphan pages.

5. **Check for broken wikilinks**:
   - **CLI** (native support):
     ```bash
     obsidian unresolved
     ```
     Returns all broken `[[wikilinks]]` directly.
   - **MCP/File tools**: Search for `[[wikilinks]]` across the vault and resolve each against existing files
   - Report: list of broken links that could become knowledge pages

6. **Check inbox**:
   - List files in `{VAULT_PATH}/{folders.inbox}`
   - Report: count and titles of unprocessed items

7. **Check for stale session logs**:
   - Find session logs older than 30 days with unfinished `- [ ]` next steps
   - Report: stale open items that may need updating

8. **Suggest knowledge gaps**:
   - Search for terms/concepts that appear in 3+ pages but have no dedicated knowledge page
   - Report: suggested new knowledge pages (frame as "worth a web search" per the reference)

9. **If `--fix` flag is set** (safe repairs only):
   - **Before any repair**, filter the work queue by `folders.protected` (see §Protected paths in `references/setup.md`). Any orphan, MOC, or related page whose path is inside a protected folder must be skipped and reported as `protected — skipped` in the health report.
   - **Rebuild the index managed block** (if `{paths.index}` is non-empty and issues were found in step 3, and `{paths.index}` itself is not inside `folders.protected`) — follow §Index management in `references/setup.md`. This is safe: the block is machine-owned and the algorithm is deterministic.
   - If `{folders.areas}` is configured, link orphan pages to the most relevant MOC
   - Add missing cross-references between related pages (same tags)
   - Do NOT auto-create knowledge pages or modify user-authored content
   - Do NOT touch content outside the index's managed block

10. **Append to wiki log** — log the lint run with a summary of findings.

11. **Report** — present a structured health report:

```
Wiki Health Report — YYYY-MM-DD
================================
Pages: X total (Y session-logs, Z knowledge, W source-summaries)
Index: {paths.index} — N entries / M pages (X missing, Y stale, Z domain-drift)
  (or "Index: disabled" if paths.index is empty)
Orphans: N pages unreachable from index and with no inbound wikilinks
Broken links: N references to non-existent pages
Inbox: N items awaiting ingestion
Stale TODOs: N open items in old session logs
Suggested pages: [list of concepts worth their own page]
```
