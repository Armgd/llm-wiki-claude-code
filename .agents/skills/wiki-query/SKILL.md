---
name: wiki-query
description: "Use this skill to query an Obsidian-based LLM wiki with a natural-language question and get a synthesized answer with wikilink citations. Triggers when the user runs the wiki-query skill (Claude: `/llm-wiki:wiki-query`), asks \"what does the wiki say about X\", \"search my wiki for Y\", or similar knowledge-lookup requests. Optionally offers to file substantial answers back into the wiki as knowledge pages."
argument-hint: "<natural-language-question>"
allowed-tools: Read, Grep, Glob, Bash, Write, mcp__obsidian__search_notes, mcp__obsidian__read_note, mcp__obsidian__read_multiple_notes, mcp__obsidian__get_notes_info, mcp__obsidian__write_note, mcp__obsidian__list_directory, mcp__plugin_llm-wiki_obsidian__search_notes, mcp__plugin_llm-wiki_obsidian__read_note, mcp__plugin_llm-wiki_obsidian__read_multiple_notes, mcp__plugin_llm-wiki_obsidian__get_notes_info, mcp__plugin_llm-wiki_obsidian__write_note, mcp__plugin_llm-wiki_obsidian__list_directory
---

# wiki-query skill (Claude: `/llm-wiki:wiki-query`)

Search the user's Obsidian wiki and synthesize an answer to their question with citations.

## Bootstrap (required)

**Resolve the skill directory first.** Set `SKILL_DIR` to the absolute path of this
skill's directory. In Claude Code, use `${CLAUDE_SKILL_DIR}` (your host substitutes it).
On other hosts (Antigravity, Codex, OpenCode, Pi, ...), substitute the absolute skill path your host reported
when it loaded this skill. A Bash step's working directory is the user's project, not the
skill dir, so every bundled-file reference below uses `$SKILL_DIR` — never a bare relative path.
Set SKILL_DIR at the start of every Bash step that sources the helper — Bash tool calls run in separate shells and do not share variables.

Read `$SKILL_DIR/references/setup.md` in full and follow it before proceeding. Do not proceed until bootstrap succeeds.

## Arguments

Natural language question, e.g. `"What's my current approach to container networking?"` (Claude: `/llm-wiki:wiki-query "What's my current approach to container networking?"`).

## Workflow

1. **Bootstrap** — run the setup bootstrap above. This gives you `VAULT_PATH`, `WIKI_SOURCE`, `folders.*` (including `folders.protected`), `paths.*`, and `io.*`. The query itself is read-only, but the optional file-back in step 6 writes — those writes must check `folders.protected` per §Protected paths in `references/setup.md`.

   **Probe I/O backend** — run via Bash:
   ```bash
   SKILL_DIR="${CLAUDE_SKILL_DIR}"   # Claude fills this; other hosts: set to the abs skill dir
   VAULT_PATH="<vault path>"          # substitute the value resolved by the bootstrap
   source "$SKILL_DIR/scripts/wiki-io.sh"
   wiki_io_probe "${VAULT_PATH}"
   wiki_qmd_probe "${VAULT_PATH}"
   echo "Backend: $WIKI_IO_BACKEND | qmd: $WIKI_QMD_AVAILABLE"
   ```
   - If `WIKI_IO_BACKEND` is `"cli"` → use CLI for all read/search/write operations. Consult `$SKILL_DIR/references/cli-patterns.md` for syntax.
   - If `WIKI_IO_BACKEND` is `"mcp"` → if this agent exposes Obsidian MCP tools
     (standalone servers expose `mcp__obsidian__*`; the Claude Code plugin-bundled
     server exposes `mcp__plugin_llm-wiki_obsidian__*`; other agents may not have
     them at all), probe the `list_directory` tool on the vault root and use MCP
     if it responds. Otherwise use file tools (Read/Write/Edit/Grep/Glob). Agents
     without MCP (e.g. Pi) always land on the CLI or file-tool tier — this is expected.
   - Commit to one I/O tier for the entire workflow. qmd availability is independent of the I/O tier.

2. **Read the index first** (only if `{paths.index}` is non-empty):
   - **CLI**: `obsidian read path="{paths.index}"` via Bash — pipe and extract the managed block
   - **MCP/File tools**: `Read {VAULT_PATH}/{paths.index}`
   - Extract content between `<!-- llm-wiki:index:start -->` / `<!-- llm-wiki:index:end -->` markers.
   - Scan for pages relevant to the question. Treat these as priority candidates.
   - If markers are missing or empty, skip this step. Do not regenerate during query.

3. **Search the wiki**:

   **If `WIKI_QMD_AVAILABLE` is `"true"`** (semantic search):
   ```bash
   SKILL_DIR="${CLAUDE_SKILL_DIR}"   # Claude fills this; other hosts: set to the abs skill dir
   source "$SKILL_DIR/scripts/wiki-io.sh"
   wiki_qmd_search "<question keywords>" 10
   ```
   - qmd returns ranked results with filepath and context snippet — use these paths directly
   - For metadata-specific lookups (e.g., "all pages tagged X", frontmatter filters), still use the I/O tier's search (CLI/MCP/Grep)
   - If qmd returns no results, fall back to the I/O tier search below and report: `(qmd returned no results, falling back to keyword search)`

   **If `WIKI_QMD_AVAILABLE` is `"false"`** (keyword search fallback):
   - **CLI**: `obsidian search query="<keywords>" limit=20` via Bash
   - **MCP**: `mcp__obsidian__search_notes` with question keywords
   - **File tools**: `Grep` across `{VAULT_PATH}/**/*.md`

   **Both paths**: browse relevant MOCs under `{folders.areas}` (if configured). Merge with priority candidates from step 2, deduplicating by path.

4. **Read relevant pages**:
   - **CLI** (context-efficient): for each page, read just the first 50 lines first:
     ```bash
     obsidian read path="<page-path>" | head -50
     ```
     Only read in full the pages that are clearly relevant.
   - **MCP**: `mcp__obsidian__read_multiple_notes` for bulk reads
   - **File tools**: multiple `Read` calls
   - Read up to 10 matching pages; follow `[[wikilinks]]` for deeper context
   - Note which pages are session logs vs knowledge pages vs source summaries

5. **Synthesize answer**:
   - Combine information from multiple pages into a coherent answer
   - Use `[[wikilinks]]` as inline citations so the user can drill deeper
   - Note the confidence level: how well-covered is this topic in the wiki?
   - If information is sparse, suggest what sources could fill the gap

6. **Offer to file**:
   - If the synthesized answer is substantial (>5 lines), ask:
     "This answer could be useful as a wiki page. Want me to file it as a knowledge page?"
   - If yes: **before each write**, verify the target path is not inside `folders.protected` (see §Protected paths in `references/setup.md`); if it is, abort with the documented message. Then create a knowledge page in `{VAULT_PATH}/{folders.resources}/<domain>/` following the `knowledge` page type from the schema, regenerate the index managed block (only if `{paths.index}` is non-empty — follow §Index management in `references/setup.md`), and append to wiki log.

7. **Report**: Present the answer with citations.
