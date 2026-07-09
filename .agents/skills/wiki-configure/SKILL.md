---
name: wiki-configure
description: Use this skill to set up (or reconfigure) the llm-wiki plugin for a user's Obsidian vault. Triggers when the user runs the wiki-configure skill (Claude: `/llm-wiki:wiki-configure`), asks to "set up llm-wiki", "configure the wiki plugin", or after first installation of the plugin. Inventories the vault, asks the user to map folders to wiki roles, writes the vault path file and the filled-in schema, and instructs the user how to set the OBSIDIAN_VAULT_PATH env var for the bundled MCP server.
allowed-tools: Read, Write, Edit, Glob, Bash
---

# wiki-configure skill (Claude: `/llm-wiki:wiki-configure`)

Interactive setup for the llm-wiki plugin. Unlike the other wiki commands, this one runs WITHOUT the bootstrap in `references/setup.md` — it's the setup itself. Obsidian MCP tools may be unavailable on first run (they need the vault path this command sets); gracefully fall back to `Glob`.

## Resolve the skill directory first

Set `SKILL_DIR` to the absolute path of this skill's directory. In Claude Code, use
`${CLAUDE_SKILL_DIR}` (your host substitutes it). On Codex, Gemini, OpenCode, or Pi,
substitute the absolute skill path your host reported when it loaded this skill. A Bash
step's working directory is the user's project, not the skill dir, so every bundled-file
reference below uses `$SKILL_DIR` — never a bare relative path. Any Bash step that copies
from `vault-files/` must first set `SKILL_DIR="${CLAUDE_SKILL_DIR}"` (Claude fills this in;
other hosts substitute the absolute skill dir instead).

## Arguments

None.

## Workflow

### 1. Detect existing configuration

- Check if `~/.config/llm-wiki/vault` exists.
  - If it exists and points to a valid directory → this is a **reconfigure** flow. Read the current vault path and its schema (if present) to diff against later.
  - If it's missing → **first-time setup**.

### 2. Prompt for vault path (first-time) or confirm (reconfigure)

- Ask the user: "Where is your Obsidian vault? (absolute path — `~` is fine)"
  - **Do not suggest a default with a specific casing.** "Obsidian" is a product name but the user's folder can be any casing — do not anchor the prompt with a capitalized example, and do not mention `ObsidianVault` or any other specific path in the question.
- **Preserve the user's casing verbatim.** Never "normalize" or "correct" capitalization in the path the user types. Not even if it looks like a proper noun was typed in lowercase. The on-disk filesystem is the single source of truth for casing.
- Expand `~` to the user's home directory.
- **Validate** the path exists and is a directory (`test -d`). Re-prompt if not.
- **Canonicalize casing from the on-disk name.** Use Bash to read the real casing:
  ```bash
  parent=$(dirname "$VAULT_PATH")
  base=$(basename "$VAULT_PATH")
  canonical=$(cd "$parent" 2>/dev/null && find . -maxdepth 1 -iname "$base" -print 2>/dev/null | head -1 | sed 's|^\./||')
  if [ -n "$canonical" ]; then VAULT_PATH="$parent/$canonical"; fi
  ```
  This guards against case-insensitive filesystems (macOS default APFS/HFS+) where the user may type a different casing than what's on disk, and ensures the vault pointer file always matches the on-disk canonical name. It's a no-op on case-sensitive filesystems.
- If the canonicalized path differs from what the user typed, show the user the corrected path once and ask them to confirm before proceeding.

### 2b. Detect Obsidian CLI and Headless

Probe for available I/O backends to pre-populate the schema:

1. **Check for Obsidian CLI**:
   ```bash
   CLI_PATH=$(command -v obsidian 2>/dev/null || echo "")
   if [ -n "$CLI_PATH" ]; then
     echo "Obsidian CLI found at: $CLI_PATH"
     if obsidian help &>/dev/null; then
       echo "Obsidian is running — CLI is fully operational"
     else
       echo "Obsidian CLI found but app is not running — CLI available when app starts"
     fi
     CLI_AVAILABLE="true"
   else
     echo "Obsidian CLI not found on PATH"
     CLI_AVAILABLE="false"
   fi
   ```

2. **Check for Obsidian Headless** (sync service — not an I/O backend):
   ```bash
   if command -v ob &>/dev/null; then
     echo "Obsidian Headless (ob) found — vault sync available without desktop app"
     HEADLESS_AVAILABLE="true"
   else
     HEADLESS_AVAILABLE="false"
   fi
   ```
   Headless requires an Obsidian account with Sync subscription and `ob login`. It keeps vault files in sync on server/CI but does not provide note read/write commands — the plugin still uses MCP or file tools for I/O in headless environments.

3. **Present findings and ask preference**:
   - If CLI found → "Obsidian CLI detected at `{CLI_PATH}`. Recommended as primary I/O backend (better context management via stdout piping). Use CLI as preferred backend? [Y/n]"
   - If CLI not found → "Obsidian CLI not detected. You can install it from Obsidian Settings → General → Command line interface. For now, the plugin will use MCP or file tools. Set I/O preference to `auto` (re-detect each session)? [Y/n]"
   - If Headless found → note: "Obsidian Headless detected — vault sync works without the desktop app (requires Obsidian account + `ob login`)."
   - Capture `IO_PREFERENCE`: `"cli"` if user confirms CLI, `"auto"` otherwise

### 2c. Detect and configure qmd (optional)

Probe for qmd, a local semantic search engine for markdown files:

1. **Check for qmd binary**:
   ```bash
   QMD_PATH=$(command -v qmd 2>/dev/null || echo "")
   if [ -n "$QMD_PATH" ]; then
     echo "qmd found at: $QMD_PATH"
     QMD_AVAILABLE="true"
   else
     echo "qmd not found on PATH (optional — semantic search will not be available)"
     QMD_AVAILABLE="false"
   fi
   ```

2. **If qmd is found, register the vault as a collection**:
   ```bash
   # Check if vault is already a collection
   if qmd collection list 2>/dev/null | grep -qF "$VAULT_PATH"; then
     echo "Vault already registered as a qmd collection"
   else
     echo "Registering vault as qmd collection..."
     qmd collection add "$VAULT_PATH" --name wiki
   fi
   ```

3. **Build the search index**:
   ```bash
   echo "Building search index..."
   qmd update
   ```

4. **Build vector embeddings**:
   - Warn the user: "Building embeddings. First run downloads ~2GB of models — this may take a few minutes."
   ```bash
   qmd embed
   ```

5. **Report**:
   - If all steps succeeded: `Semantic search enabled via qmd.`
   - If any step after probe failed: warn, set `QMD_AVAILABLE="false"`, continue. qmd setup failure is non-blocking.

### 3. Inventory the vault

- Try `mcp__obsidian__list_directory` on the vault root.
- If MCP is unavailable (expected on first run), use `Glob` with the pattern `{vault}/*` to list top-level folders.
- Present the list of folders found, with file counts per folder (use `Glob '{folder}/*.md'` to count).

### 4. Map folders to roles

Ask the user to map each **required** role. For each, propose a best guess using case-insensitive substring matching (e.g. `00 - Inbox` matches `inbox`). Accept Enter to confirm or let the user type a different folder name.

Required roles (must be mapped):
- `inbox` — incoming sources
- `projects` — where session logs go
- `resources` — where knowledge pages and source summaries go
- `system` — where the wiki schema, log, templates, and archive live

Then ask about **optional** roles. User may leave each empty:
- `areas` — where MOCs live (skill skips MOC updates if unset)
- `notes` — fallback for unclassified content (skill asks each time if unset)

### 4c. Ask about protected folders

Protected folders are paths skills must never write/move/delete into (reads are still allowed). The defaults cover the two zones the schema relies on the user owning.

- Compute default candidates: `{SYSTEM_FOLDER}/Templates` and `{SYSTEM_FOLDER}/Archive/Sources` — these match `paths.templates` and `paths.archive_sources` later in the schema.
- Ask: `Protect Templates and Archive from LLM writes? [Y/n]` — Enter accepts; `n` starts with an empty list.
- Follow-up free-text: `Any other folders to protect from LLM writes? (comma-separated vault-relative paths, blank to skip)`
- Capture as `PROTECTED_FOLDERS` — an array (possibly empty) of vault-relative path strings. Strip leading/trailing whitespace and any leading `/` on each entry.

### 5. Ask about project sub-structure

- Inventory the mapped projects folder (MCP or Glob).
- Show the user what's there and offer shape choices:
  - (a) Work/Personal split (e.g. `Work/`, `Personal/` folders under Projects)
  - (b) Client-based (e.g. `Work/{Client}/{Project}/`)
  - (c) Flat (projects directly under Projects)
  - (d) Other — ask the user to describe their convention in one sentence
- Capture the chosen description as free text for the schema's `Project Mapping` section.

### 6. Detect (or propose) an index note

The index is an optional content-oriented catalog the LLM maintains inside a user-facing note (see schema §index). Its job is to let `wiki-query` "read the index first, then drill in."

- **Scan for an existing index note**:
  - Look at the vault root first. If a note with `type: index` in frontmatter exists there, propose its path.
  - If none at root, search the top level for notes whose filename matches `Home.md`, `Index.md`, or `Dashboard.md` (case-insensitive).
  - Fallback search: `Grep -l "^type: index$" {VAULT_PATH}/**/*.md` (MCP equivalent: `mcp__obsidian__search_notes` with `searchFrontmatter: true`).

- **Ask the user** based on what you found:
  - **Found one** → "You have an index note at `{path}`. Use this as the wiki index? [Y/n]" Enter accepts.
  - **Found none** → "No index note detected. Options:
    - (a) Create `Home.md` at vault root (blank, with `type: index` frontmatter + managed block)
    - (b) Use a machine-only index at `_System/wiki-index.md`
    - (c) Skip the index layer (wiki-query will search directly instead)"
  - Capture the chosen path as `INDEX_PATH`, or empty string for (c).

- **Preserve user content**. If the user's chosen note already exists and has content, **do not rewrite it**. The skill only adds the managed block on first use of `wiki-capture`/`wiki-ingest`, and only appends it after a `---` separator (never inside existing sections).

### 7. Ask operational values

- Inbox nudge threshold (default 5)
- Wiki-source identifier (default `claude-code`)

### 8. Confirm & write artifacts

Show the user a summary of the configuration. Ask: "Write this to `{vault}/_System/wiki-schema.md` and `~/.config/llm-wiki/vault`? [y/N]"

On confirmation:

1. **Write the vault path file** — `~/.config/llm-wiki/vault`:
   - Create the `~/.config/llm-wiki/` directory if missing
   - Write the absolute vault path as the sole line of the file (no trailing newline issues — use `printf "%s\n" "$VAULT_PATH"`)

2. **Read the template** — `$SKILL_DIR/vault-files/wiki-schema.md.template`

3. **Substitute all `{{PLACEHOLDER}}` markers**:
   - `{{VAULT_PATH}}` → absolute vault path
   - `{{WIKI_SOURCE}}` → chosen identifier
   - `{{INBOX_THRESHOLD}}` → chosen threshold
   - `{{INBOX_FOLDER}}` → mapped inbox folder
   - `{{PROJECTS_FOLDER}}` → mapped projects folder
   - `{{RESOURCES_FOLDER}}` → mapped resources folder
   - `{{SYSTEM_FOLDER}}` → mapped system folder
   - `{{AREAS_FOLDER}}` → mapped areas folder or empty string
   - `{{NOTES_FOLDER}}` → mapped notes folder or empty string
   - `{{INDEX_PATH}}` → chosen index path (e.g. `Home.md`) or empty string if the user skipped
   - `{{PROTECTED_FOLDERS}}` → inline YAML array of the captured `PROTECTED_FOLDERS` list. Examples: `["_System/Templates", "_System/Archive/Sources"]` or `[]` when the user opted out of everything. Quote each entry; comma-separate.
   - `{{IO_PREFERENCE}}` → chosen I/O preference (`"cli"`, `"mcp"`, or `"auto"`)
   - `{{CLI_PATH}}` → path to obsidian binary, or empty string
   - `{{HEADLESS_AVAILABLE}}` → `"true"` or `"false"`
   - `{{QMD_AVAILABLE}}` → `"true"` or `"false"`
   - `{{PROJECT_MAPPING_DESCRIPTION}}` → chosen sub-structure description

4. **Write the filled schema** to `{vault}/_System/wiki-schema.md`.

5. **Seed the vault** (first-time only):
   - Create `{vault}/_System/Templates/` if missing
   - Create `{vault}/_System/Archive/Sources/` if missing
   - If `{vault}/_System/wiki-log.md` is missing, copy `$SKILL_DIR/vault-files/wiki-log.md` to it
   - For each file in `$SKILL_DIR/vault-files/Templates/`, copy to `{vault}/_System/Templates/` only if not already present (never overwrite user content)

6. **Seed the index note** (only if `INDEX_PATH` is non-empty):
   - If `{vault}/{INDEX_PATH}` **exists**: do NOT modify it. The managed block will be created lazily on the first `wiki-capture` or `wiki-ingest` call that needs to write entries.
   - If `{vault}/{INDEX_PATH}` **does not exist** (the user chose to create a new one): write a minimal file with `type: index` frontmatter and an empty managed block:

     ```
     ---
     type: index
     tags: [dashboard, navigation]
     ---

     # {filename without extension}

     <!-- llm-wiki:index:start -->
     ## Wiki Index

     > Auto-maintained by llm-wiki. The block between the `llm-wiki:index:start` and `llm-wiki:index:end` markers is regenerated on every wiki operation. Edits inside will be overwritten; edits outside the markers are preserved.

     ### Knowledge

     _(none yet)_

     ### Sources

     _(none yet)_
     <!-- llm-wiki:index:end -->
     ```
   - Create parent directories if the path includes them (e.g. `_System/wiki-index.md`).

7. **Create any named role folders** that don't yet exist in the vault (ask before creating each one).

8. **Offer to scaffold a vault-root `AGENTS.md`** (freeform per-vault LLM guidance — see §Read optional vault-root override file in `references/setup.md`):
   - Skip silently if `{VAULT_PATH}/AGENTS.md` already exists. Never overwrite.
   - Ask: `Scaffold a vault-root AGENTS.md for vault-specific LLM guidance? [y/N]` — default is no.
   - On accept: copy `$SKILL_DIR/vault-files/AGENTS.md.template` verbatim to `{VAULT_PATH}/AGENTS.md`. No template substitution — the file is freeform context the user fills in.
     Codex/OpenCode/Pi read `AGENTS.md` natively; Claude/Gemini users who want vault-dir context can add a one-line `@AGENTS.md` `CLAUDE.md`/`GEMINI.md` themselves — mention this, don't auto-create it.

### 9. Reconfigure diff (only if this is a reconfigure flow)

- Before step 8's write, compare the existing schema's `Vault Configuration` section with the new one.
- Present a unified diff of the changed lines.
- Ask: "Apply these changes? [y/N]"
- If no changes would be made, print `No changes — configuration already matches.` and exit without writing.

### 10. Tell the user how to set up I/O backends

Print the relevant instructions based on detected backends:

**Always print (MCP fallback)**:
```
To enable the bundled Obsidian MCP server (fallback when CLI is unavailable),
add this line to your shell profile (~/.zshrc, ~/.bashrc, etc.):

  export OBSIDIAN_VAULT_PATH="{VAULT_PATH}"

Then restart Claude Code.
```

**If CLI was detected, also print**:
```
Obsidian CLI detected at {CLI_PATH}.
The plugin will prefer CLI for better context management.
Make sure Obsidian is running when you use wiki commands.
```

**If CLI was NOT detected, also print**:
```
Tip: Install Obsidian CLI for better performance:
  Obsidian → Settings → General → Command line interface → Enable
```

**If Headless was detected, also print**:
```
Obsidian Headless detected — vault sync works without the desktop app.
On server/CI, Headless keeps vault files in sync via Obsidian Sync.
Note: Headless is a sync service, not an I/O backend — the plugin
uses MCP or file tools to read/write notes in headless environments.
Requires: Obsidian account + Sync subscription + `ob login`.
```

**If qmd was configured, also print**:
```
qmd semantic search enabled.
Collection "wiki" registered for vault at {VAULT_PATH}.
To re-index after adding many files manually: qmd update && qmd embed
```

**If qmd was NOT found, also print**:
```
Tip: Install qmd for semantic search at scale (optional):
  npm install -g @tobilu/qmd
  Then re-run wiki-configure (Claude: /llm-wiki:wiki-configure) to register your vault.
```

Use the actual vault path and CLI path in all examples, not placeholders.

### 11. Log it

- Append an entry to `{vault}/_System/wiki-log.md`:

```
## [YYYY-MM-DD] configure | initial setup
- Vault: {VAULT_PATH}
- Folders mapped: inbox ({folder}), projects ({folder}), resources ({folder}), system ({folder})
- Optional: areas ({folder or "unset"}), notes ({folder or "unset"})
- Protected: {N} path(s)
- qmd: {QMD_AVAILABLE}
- Index: {INDEX_PATH or "unset"}
```

### 12. Final report

```
Configured successfully.
Vault path: {VAULT_PATH}
Schema: {vault}/_System/wiki-schema.md
Vault path file: ~/.config/llm-wiki/vault

Next:
1. Add export OBSIDIAN_VAULT_PATH="{VAULT_PATH}" to your shell profile
2. Restart Claude Code
3. Run wiki-capture (Claude: /llm-wiki:wiki-capture) at the end of your next work session
```
