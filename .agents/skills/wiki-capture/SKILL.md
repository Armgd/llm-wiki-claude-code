---
name: wiki-capture
description: "Use this skill to capture session knowledge into an Obsidian-based LLM wiki. Triggers when the user runs the wiki-capture skill (Claude: `/llm-wiki:wiki-capture`), asks to \"capture this session\", \"file this session into the wiki\", or similar end-of-session knowledge persistence requests. Produces a session log in the vault plus optional knowledge page creation and enrichments."
argument-hint: "[project-name]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# wiki-capture skill (Claude: `/llm-wiki:wiki-capture`)

Extract and file knowledge from the current session into the user's Obsidian vault.

## Bootstrap (required)

**Resolve the skill directory first.** Set `SKILL_DIR` to the absolute path of this
skill's directory. In Claude Code, use `${CLAUDE_SKILL_DIR}` (your host substitutes it).
On other hosts (Antigravity, Codex, OpenCode, Pi, ...), substitute the absolute skill path your host reported
when it loaded this skill. A Bash step's working directory is the user's project, not the
skill dir, so every bundled-file reference below uses `$SKILL_DIR` — never a bare relative path.
Set SKILL_DIR at the start of every Bash step that sources the helper — Bash tool calls run in separate shells and do not share variables.

Read `$SKILL_DIR/references/setup.md` in full and follow it before proceeding. It tells you how to resolve the vault path, read and parse the schema, and handle optional folder roles. Do not proceed with capture until bootstrap succeeds; if it aborts, propagate its message to the user and stop.

## Arguments

Optional project name, e.g. `my-awesome-project` (Claude: `/llm-wiki:wiki-capture my-awesome-project`). If omitted, infer from the current working directory or ask the user.

## Workflow

1. **Bootstrap** — run the setup bootstrap above. This gives you `VAULT_PATH`, `WIKI_SOURCE`, `folders.*` (including `folders.protected`), `paths.*`, and `io.*`. Any write step below must first check the target against `folders.protected` per §Protected paths in `references/setup.md`.

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
   - If `WIKI_IO_BACKEND` is `"filetool"` → use file tools (Read/Write/Edit/Grep/Glob).
   - Commit to one I/O tier for the entire workflow. qmd availability is independent of the I/O tier.

2. **Gather session context**:
   - Look for the session change manifest written by the notify hook. If the host exposes this session's id as an env var (Claude Code: `$CLAUDE_SESSION_ID`), use `/tmp/wiki-session-changes.$CLAUDE_SESSION_ID`. Otherwise pick the newest (`ls -t /tmp/wiki-session-changes.* 2>/dev/null | head -1`); if several manifests exist, mention in the final report that concurrent sessions may have interleaved. If none exist, skip this step.
   - Review the conversation for: decisions made, bugs found + fixes, patterns discovered, current state of work, blockers, next steps

3. **Search for related wiki content**:

   **If `WIKI_QMD_AVAILABLE` is `"true"`** (semantic search):
   ```bash
   SKILL_DIR="${CLAUDE_SKILL_DIR}"   # Claude fills this; other hosts: set to the abs skill dir
   source "$SKILL_DIR/scripts/wiki-io.sh"
   wiki_qmd_search "<session keywords>" 10
   ```
   - Use the ranked paths to find related pages efficiently
   - If qmd returns no results, fall back to the I/O tier search below

   **If `WIKI_QMD_AVAILABLE` is `"false"`** (keyword search fallback):
   - **CLI**: `obsidian search query="<keywords>" limit=20` via Bash — pipe through `head` if results are numerous
   - **File tools**: `Grep` over `{VAULT_PATH}/**/*.md`

   **Both paths**: check if knowledge pages already exist for discovered patterns (avoid duplicates). Identify existing notes that could be enriched.

4. **Map project location**:
   - Match CWD or the provided project name to a path under `{folders.projects}`, following the schema's `Project Mapping` section
   - Use fuzzy matching (case-insensitive, check git remote for client/org hints)
   - If no match, fall back to `{folders.notes}` if configured; otherwise ask the user

5. **Write session log**:
   - **Before writing**, verify the target path is not inside `folders.protected` (see §Protected paths in `references/setup.md`). If it is, abort with the documented message.
   - Create `{VAULT_PATH}/{folders.projects}/<resolved-sub-structure>/session-log-YYYY-MM-DD.md`
   - Use the `session-log` page type from the schema (Decisions, Findings, State, Next Steps)
   - Set `wiki-source: {WIKI_SOURCE}` in frontmatter
   - Link to knowledge pages with `[[wikilinks]]`
   - **CLI**: `obsidian create path="<resolved-path>" content="<full-content>" silent` via Bash
   - **File tools**: `Write {VAULT_PATH}/<path>`
   - Once the session log is written, clear the manifest read in step 2 (`: > <manifest>`) so a second capture in this session doesn't re-report the same changes.

6. **Create/update knowledge pages** (for significant findings):
   - **Before writing each page**, verify the target path is not inside `folders.protected` (see §Protected paths in `references/setup.md`). If it is, abort with the documented message.
   - For each pattern, technique, or concept worth persisting beyond this session:
     - If a knowledge page already exists → update it
     - If new → create in `{VAULT_PATH}/{folders.resources}/<domain>/<topic>.md`
   - **Auto-capture** (write directly): technical decisions, bug root causes, fix patterns, new techniques
   - **Prompt first**: if the finding is ambiguous or would enrich an existing user-authored note

7. **Enrich existing notes** (prompt first):
   - **Before proposing an enrichment**, verify the target note is not inside `folders.protected` (see §Protected paths in `references/setup.md`). If it is, skip the enrichment silently — do not prompt the user about it.
   - If session findings are relevant to existing notes, propose appending an enrichment
   - Show the user what will be added and where
   - On approval: append `> [!claude] Added YYYY-MM-DD` callout block after a `---` separator
   - Update frontmatter: add `wiki-updated` and `wiki-updated-by` fields (value: `{WIKI_SOURCE}`)

8. **Update MOCs**:
   - If `{folders.areas}` is configured and new pages were created, add links to the relevant MOC
   - Read the MOC first to find the right section

9. **Update the index** (only if `{paths.index}` is non-empty):
   - Follow the §Index management algorithm in `references/setup.md`.
   - Rebuild the managed block from the current set of `wiki-source`-tagged `knowledge` and `source-summary` pages.
   - Session logs (this capture's output) are **never** listed in the index — they live in the wiki log.
   - Safe order: write the new knowledge pages first (step 6), then regenerate the index block. Never combine the two into one write.

10. **Append to wiki log**:
    - Append an entry to `{VAULT_PATH}/{paths.wiki_log}` following the log format in the schema
    - List all pages created, updated, and enriched

11. **Report**: Summarize what was filed — pages created, pages updated, enrichments made, and whether the index was regenerated.
