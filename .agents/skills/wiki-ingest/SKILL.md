---
name: wiki-ingest
description: "Use this skill to ingest an external source (article, PDF, meeting notes) into an Obsidian-based LLM wiki. Triggers when the user runs the wiki-ingest skill (Claude: `/llm-wiki:wiki-ingest`), asks to \"ingest this article\", \"summarize and file this source\", or similar source-processing requests. Produces a source summary page cross-referenced with existing knowledge and moves the original to the vault's archive."
argument-hint: "<path-to-source-note-relative-to-vault>"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, mcp__obsidian__search_notes, mcp__obsidian__read_note, mcp__obsidian__write_note, mcp__obsidian__patch_note, mcp__obsidian__update_frontmatter, mcp__obsidian__get_frontmatter, mcp__obsidian__list_directory, mcp__obsidian__move_note, mcp__obsidian__move_file
---

# wiki-ingest skill (Claude: `/llm-wiki:wiki-ingest`)

Process an external source into a structured summary filed in the user's Obsidian vault.

## Bootstrap (required)

**Resolve the skill directory first.** Set `SKILL_DIR` to the absolute path of this
skill's directory. In Claude Code, use `${CLAUDE_SKILL_DIR}` (your host substitutes it).
On Codex, Gemini, OpenCode, or Pi, substitute the absolute skill path your host reported
when it loaded this skill. A Bash step's working directory is the user's project, not the
skill dir, so every bundled-file reference below uses `$SKILL_DIR` — never a bare relative path.
Set SKILL_DIR at the start of every Bash step that sources the helper — Bash tool calls run in separate shells and do not share variables.

Read `$SKILL_DIR/references/setup.md` in full and follow it before proceeding. Do not proceed until bootstrap succeeds.

## Arguments

Path to the source note, relative to the vault root, e.g. `"00 - Inbox/The AI Layoff Trap.md"` (Claude: `/llm-wiki:wiki-ingest "00 - Inbox/The AI Layoff Trap.md"`).

## Workflow

1. **Bootstrap** — run the setup bootstrap above. This gives you `VAULT_PATH`, `WIKI_SOURCE`, `folders.*` (including `folders.protected`), `paths.*`, and `io.*`. Any write or move step below must first check the target against `folders.protected` per §Protected paths in `references/setup.md`.

   **Probe I/O backend** — run via Bash:
   ```bash
   SKILL_DIR="${CLAUDE_SKILL_DIR}"   # Claude fills this; other hosts: set to the abs skill dir
   source "$SKILL_DIR/scripts/wiki-io.sh"
   wiki_io_probe "${VAULT_PATH}"
   wiki_qmd_probe "${VAULT_PATH}"
   echo "Backend: $WIKI_IO_BACKEND | qmd: $WIKI_QMD_AVAILABLE"
   ```
   - If `WIKI_IO_BACKEND` is `"cli"` → use CLI for all read/search/write operations. Consult `$SKILL_DIR/references/cli-patterns.md` for syntax.
   - If `WIKI_IO_BACKEND` is `"mcp"` → if this agent exposes Obsidian MCP tools
     (Claude/Gemini/OpenCode name them `mcp__obsidian__*`; other agents may not have
     them at all), probe `mcp__obsidian__list_directory` on the vault root and use MCP
     if it responds. Otherwise use file tools (Read/Write/Edit/Grep/Glob). Agents
     without MCP (e.g. Pi) always land on the CLI or file-tool tier — this is expected.
   - Commit to one I/O tier for the entire workflow. qmd availability is independent of the I/O tier.

2. **Read the source**:
   - **CLI**: `obsidian read path="<argument>"` via Bash — pipe through `head -100` for initial scan, then read in full if needed
   - **MCP**: `mcp__obsidian__read_note` with the argument path
   - **File tools**: `Read {VAULT_PATH}/<argument>`
   - If the source has images, read them separately for additional context

3. **Analyze and discuss**:
   - Identify key claims, arguments, findings, and takeaways
   - Present a summary of key points to the user
   - Ask: "What stands out to you? Anything to emphasize or skip?"
   - Determine the domain (e.g. AI, infrastructure, career, personal)

4. **Search for related content**:

   **If `WIKI_QMD_AVAILABLE` is `"true"`** (semantic search):
   ```bash
   SKILL_DIR="${CLAUDE_SKILL_DIR}"   # Claude fills this; other hosts: set to the abs skill dir
   source "$SKILL_DIR/scripts/wiki-io.sh"
   wiki_qmd_search "<keywords from key claims>" 10
   ```
   - Use the ranked paths to find related pages and potential contradictions
   - If qmd returns no results, fall back to the I/O tier search below

   **If `WIKI_QMD_AVAILABLE` is `"false"`** (keyword search fallback):
   - **CLI**: `obsidian search query="<keywords from key claims>" limit=20` via Bash
   - **MCP**: `mcp__obsidian__search_notes` with keywords
   - **File tools**: `Grep` across `{VAULT_PATH}/**/*.md`

   **Both paths**: identify potential cross-references and contradictions.

5. **Write source summary**:
   - **Before writing**, verify the target path is not inside `folders.protected` (see §Protected paths in `references/setup.md`). If it is, abort with the documented message.
   - Create `{VAULT_PATH}/{folders.resources}/<domain>/<source-title> — Summary.md`
   - Use the `source-summary` page type from the schema (Key Claims, Relevance, Contradictions, Original)
   - The `Original` link should point to `[[{paths.archive_sources}/<filename>|Original]]`
   - Set `wiki-source: {WIKI_SOURCE}` in frontmatter

6. **Create/update knowledge pages**:
   - **Before writing each page**, verify the target path is not inside `folders.protected` (see §Protected paths in `references/setup.md`). If it is, abort with the documented message.
   - If the source introduces new concepts worth their own page, create knowledge pages in `{VAULT_PATH}/{folders.resources}/<domain>/`
   - If existing knowledge pages are relevant, update them with new information (use enrichment callout)

7. **Update MOCs**:
   - If `{folders.areas}` is configured, add a link to the source summary in the relevant MOC
   - If no suitable MOC exists for the domain, note this in lint suggestions

8. **Flag contradictions**:
   - If the source contradicts existing wiki content, note it explicitly in:
     - The source summary page (Contradictions section)
     - The contradicted page (via enrichment callout)
     - The wiki log entry

9. **Archive the source**:
   - **Before moving**, verify the destination `{paths.archive_sources}` is not itself inside `folders.protected` (see §Protected paths in `references/setup.md`). If it is, abort with the documented message rather than attempting the move.
   - Create the archive directory if it doesn't yet exist
   - **CLI**: use `obsidian eval` to move (preserves backlinks):
     ```bash
     obsidian eval "await app.fileManager.renameFile(app.vault.getAbstractFileByPath('<argument>'), '{paths.archive_sources}/<filename>')"
     ```
     If eval fails, fall back to the MCP or file-tool method below.
   - **MCP**: `mcp__obsidian__move_note` — preserves inbound `[[wikilinks]]`.
   - **File tools**: `Bash mv {VAULT_PATH}/<argument> {VAULT_PATH}/{paths.archive_sources}/` **and** rewrite inbound wikilinks: `Grep` the vault for the old filename and `Edit` each match. Flag any link that can't be cleanly rewritten in the wiki log.

10. **Update the index** (only if `{paths.index}` is non-empty):
    - Follow the §Index management algorithm in `references/setup.md`.
    - Rebuild the managed block so the new source summary (and any new knowledge pages) appear under their domain.
    - Safe order: write the new pages first, archive the original, then regenerate the index block.

11. **Append to wiki log**:
    - Append an entry to `{VAULT_PATH}/{paths.wiki_log}` listing: summary created, pages updated, contradictions flagged

12. **Report**: Summarize what was created and connected. Mention whether the index was regenerated.
