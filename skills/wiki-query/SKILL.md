---
name: wiki-query
description: Use this skill to query an Obsidian-based LLM wiki with a natural-language question and get a synthesized answer with wikilink citations. Triggers when the user runs the /llm-wiki:wiki-query slash command, asks "what does the wiki say about X", "search my wiki for Y", or similar knowledge-lookup requests. Optionally offers to file substantial answers back into the wiki as knowledge pages.
argument-hint: "<natural-language-question>"
allowed-tools: Read, Grep, Glob, Bash, Write, mcp__obsidian__search_notes, mcp__obsidian__read_note, mcp__obsidian__read_multiple_notes, mcp__obsidian__get_notes_info, mcp__obsidian__write_note, mcp__obsidian__list_directory
---

# /llm-wiki:wiki-query

Search the user's Obsidian wiki and synthesize an answer to their question with citations.

## Bootstrap (required)

Read `${CLAUDE_PLUGIN_ROOT}/references/setup.md` in full and follow it before proceeding. Do not proceed until bootstrap succeeds.

## Arguments

Natural language question (example: `/llm-wiki:wiki-query "What's my current approach to container networking?"`).

## Workflow

1. **Bootstrap** — run the setup bootstrap above. This gives you `VAULT_PATH`, `WIKI_SOURCE`, `folders.*`, `paths.*`, and `io.*`.

   **Probe I/O backend** — run via Bash:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/scripts/wiki-io.sh"
   wiki_io_probe "${VAULT_PATH}"
   wiki_qmd_probe "${VAULT_PATH}"
   echo "Backend: $WIKI_IO_BACKEND | qmd: $WIKI_QMD_AVAILABLE"
   ```
   - If `WIKI_IO_BACKEND` is `"cli"` → use CLI for all read/search/write operations. Consult `${CLAUDE_PLUGIN_ROOT}/references/cli-patterns.md` for syntax.
   - If `WIKI_IO_BACKEND` is `"mcp"` → attempt `mcp__obsidian__list_directory` on vault root. If it responds, use MCP. If not, use file tools (Read/Write/Edit/Grep/Glob).
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
   source "${CLAUDE_PLUGIN_ROOT}/scripts/wiki-io.sh"
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
   - If yes: create a knowledge page in `{VAULT_PATH}/{folders.resources}/<domain>/` following the `knowledge` page type from the schema, then regenerate the index managed block (only if `{paths.index}` is non-empty — follow §Index management in `references/setup.md`), then append to wiki log.

7. **Report**: Present the answer with citations.
