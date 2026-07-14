# llm-wiki Setup Bootstrap

Every wiki operation (`/wiki-capture`, `/wiki-ingest`, `/wiki-query`, `/wiki-lint`) shares this bootstrap. Each skill's SKILL.md instructs the LLM to read this file first.

> **Resolving bundled files.** This file and the helpers it references (`scripts/wiki-io.sh`,
> `references/cli-patterns.md`) live in the running skill's directory. A Bash step's working
> directory is the user's project, NOT the skill dir, so you must use an absolute path.
> The calling SKILL.md sets `SKILL_DIR` to the skill's absolute directory before invoking
> this bootstrap (Claude Code fills it from `${CLAUDE_SKILL_DIR}`; other hosts substitute the
> skill's absolute path they were given). Every `source`/read below uses `$SKILL_DIR`.

## Bootstrap Steps

> **"Abort" semantics** — when a bootstrap step below says *abort with: `<message>`*, do exactly this: print the message to the user and stop the skill. Do not call any write tools, do not attempt a fallback path, do not guess a vault path.

1. **Resolve the vault path and schema path.**
   - Read `~/.config/llm-wiki/vault`.
   - If the file is missing or its first line is empty, abort with: `llm-wiki vault not configured — run the wiki-configure skill (Claude: /llm-wiki:wiki-configure) first.`
   - Line 1 is the absolute path to the user's Obsidian vault root. Call this `VAULT_PATH`. Preserve it verbatim (it may contain spaces).
   - Line 2, if present, is the vault-relative path to the schema file. Call this `SCHEMA_PATH`. If line 2 is absent or empty (pointer files written before the system folder became remappable), default to `_System/wiki-schema.md`.

2. **Read the schema.**
   - Read `{VAULT_PATH}/{SCHEMA_PATH}`.
   - If missing, abort with: `Wiki schema not found at {VAULT_PATH}/{SCHEMA_PATH} — run the wiki-configure skill (Claude: /llm-wiki:wiki-configure).`
   - If the file contains any `{{PLACEHOLDER}}` markers (e.g. `{{VAULT_PATH}}`, `{{INBOX_FOLDER}}`), abort with: `Schema not yet filled in — run the wiki-configure skill (Claude: /llm-wiki:wiki-configure).`

3. **Parse the `Vault Configuration` section of the schema.**

   Expected shape:

   ```
   ## Vault Configuration

   - vault_path: /absolute/path/to/vault
   - wiki_source: claude-code
   - inbox_threshold: 5
   - io:
     - cli_path: /usr/local/bin/obsidian  # or empty
     - headless: false                 # "true" | "false"
     - qmd: false                     # "true" | "false" — qmd semantic search
   - folders:
     - inbox: "00 - Inbox"           # required
     - projects: "01 - Projects"     # required
     - resources: "03 - Resources"   # required
     - system: "_System"             # required
     - areas: "02 - Areas"           # optional — empty string if unset
     - notes: "04 - Notes"           # optional — empty string if unset
     - protected: ["_System/Templates", "_System/Archive/Sources"]  # optional — paths skills must never write/move/delete
   - paths:
     - wiki_log: "_System/wiki-log.md"
     - templates: "_System/Templates"
     - archive_sources: "_System/Archive/Sources"
     - index: "Home.md"               # optional — empty string or missing to skip index operations
   ```

   Extract:
   - `WIKI_SOURCE` — used when writing the `wiki-source` frontmatter field on new pages
   - `INBOX_THRESHOLD` — used by the inbox-nudge hook only; skills can ignore
   - `folders.*` — the vault's folder role mapping. Use these everywhere you'd otherwise hardcode PARA folder names. `folders.protected` is a list (possibly empty) of vault-relative paths skills must never write/move/delete into — see §Protected paths.
   - `paths.*` — derived paths (wiki_log, templates, archive_sources, **index**)
   - `io.cli_path` — path to the `obsidian` binary at configure time (empty if not installed). Informational — the runtime probe (§Backend availability) always runs and its result is authoritative. Ignore any other `io` field a legacy schema may carry (e.g. `preference`).
   - `io.headless` — whether Obsidian Headless (`ob`) is available
   - `io.qmd` — whether qmd is installed and the vault is registered as a collection. When `true`, skills prefer `qmd query` for content search.

4. **Required vs optional roles.**
   - Required: `inbox`, `projects`, `resources`, `system`. If any of these is missing or empty, abort: `Schema missing required folder role {role} — re-run the wiki-configure skill (Claude: /llm-wiki:wiki-configure).`
   - Optional: `areas`, `notes`. These may be empty strings.
     - If `folders.areas` is empty → **skip MOC updates silently** (no error, no prompt).
     - If `folders.notes` is empty → **ask the user** where to file unclassified content instead of defaulting to a directory.
   - Optional: `paths.index`. May be missing or empty.
     - If `paths.index` is empty or missing → **skip index operations silently** (no error, no prompt).
     - If set but the file doesn't exist → create it with an empty managed block on first write (see §Index management below). Do not abort.
   - Optional: `folders.protected`. May be missing or an empty list — treat as no protection. Pre-migration schemas without this field parse as `[]`.
   - Optional: `io.*` fields. If `io` section is missing entirely (pre-migration schemas), treat as `cli_path: ""`, `headless: false`, `qmd: false`. This ensures backward compatibility with schemas created before the CLI migration.

5. **Read optional vault-root override file.**
   - Check for `{VAULT_PATH}/AGENTS.md`. If absent, fall back to `{VAULT_PATH}/CLAUDE.md` (for vaults set up before the rename).
   - If present, read it in full and treat its contents as additional advisory guidance for the current operation — vault-specific notes, conventions, off-limits zones beyond `folders.protected`, or anything the schema can't express.
   - This file is freeform; it does NOT override the schema. Structural decisions (folder roles, page types, protected paths) come from the schema. `AGENTS.md` is for context the schema can't express.
   - If neither exists, proceed silently — this file is optional.

## I/O strategy — two-tier probe

llm-wiki uses a two-tier I/O strategy. At bootstrap, the skill probes backends in order and commits to the first available one for the entire workflow.

**Tier 1 — Obsidian CLI** (preferred):
- Runs `source "$SKILL_DIR/scripts/wiki-io.sh" && wiki_io_probe "${VAULT_PATH}"` via Bash
- If `WIKI_IO_BACKEND` is `"cli"`, use CLI commands for all note operations
- **Advantage**: output goes to stdout, enabling `| head`, `| grep`, `| wc -l` for context management
- **Requirement**: user has enabled CLI in Obsidian (Settings → General → Command line interface) and the Obsidian desktop app is running
- Consult `$SKILL_DIR/references/cli-patterns.md` for command syntax

**Tier 2 — File tools** (fallback):
- If CLI is unavailable (user hasn't enabled it, or Obsidian is not running), use Read/Write/Edit/Grep/Glob directly on vault files
- **Advantage**: always works — no external dependencies
- **Caveat**: no wikilink resolution, no backlink-safe moves, no template engine

**Probe once, commit fully.** Never mix tiers in a single skill invocation. If you branch to a lower tier, say so once in the user-facing report: `(note: using {tier} — {reason})`. One exemption: the §Index management rewrite below always uses Read/Write file tools for the marker-bounded block, whatever tier is active — that rewrite needs whole-file control and is exempt from this rule.

### Obsidian Headless (not an I/O tier)

Obsidian Headless (`ob`) is a **sync service**, not a note I/O backend. It keeps vault files in sync across devices without the desktop app using Obsidian Sync's end-to-end encryption.

- **Requirement**: Obsidian account + Obsidian Sync subscription + `ob login`
- **What it does**: syncs vault files to/from Obsidian's servers. Useful for server/CI environments where the desktop app can't run.
- **What it does NOT do**: it has no `read`, `search`, `create`, or `move` commands. It is not a substitute for the CLI.
- **How it helps llm-wiki**: on a server, Headless keeps the vault files fresh via Sync, and the plugin uses file tools (Tier 2) to read/write those files.

The `io.headless` schema field records whether `ob` was detected at configure time. Skills do not branch on it — they branch on CLI/filetool only.

## Backend availability — detect and branch

### Probe sequence

Run this Bash block once at the start of every skill (after resolving VAULT_PATH):

```bash
SKILL_DIR="<absolute skill dir>"   # substitute (Claude Code: ${CLAUDE_SKILL_DIR})
VAULT_PATH="<vault path>"          # substitute the value resolved in bootstrap step 1
source "$SKILL_DIR/scripts/wiki-io.sh"
wiki_io_probe "${VAULT_PATH}"
echo "Backend: $WIKI_IO_BACKEND"
```

`SKILL_DIR` and `VAULT_PATH` were resolved outside the shell (bootstrap steps), so substitute their literal values — Bash steps run in separate shells and share no variables.

The script sets `WIKI_IO_BACKEND` to `"cli"` or `"filetool"`.

- If `WIKI_IO_BACKEND` is `"cli"` → use CLI for all operations below.
- If `WIKI_IO_BACKEND` is `"filetool"` → use file tools for all operations.

### Two-tier fallback table

| Operation | CLI (Tier 1) | File tools (Tier 2) |
|---|---|---|
| **List directory** | `obsidian search query="path:folder/"` via Bash | `Glob '{VAULT_PATH}/<folder>/*'` |
| **Search notes** | `obsidian search query="..." limit=N` via Bash | `Grep` over `{VAULT_PATH}/**/*.md` |
| **Read note** | `obsidian read path="..."` via Bash (pipe to `head -N` for context control) | `Read {VAULT_PATH}/<path>` |
| **Read multiple** | Multiple `obsidian read` via Bash loop | Multiple `Read` calls |
| **Create note** | `obsidian create path="..." content="..." silent` via Bash | `Write {VAULT_PATH}/<path>` |
| **Append to note** | `obsidian append path="..." content="..."` via Bash | `Edit {VAULT_PATH}/<path>` |
| **Read frontmatter** | `obsidian property:read path="..." name="..."` via Bash | `Read` first ~30 lines, parse YAML |
| **Set frontmatter** | `obsidian property:set path="..." name="..." value="..."` via Bash | `Edit` on the `---` YAML block |
| **Move note** | `obsidian eval "await app.fileManager.renameFile(...)"` via Bash (preserves backlinks) | Bash `mv` + Grep/Edit to rewrite inbound `[[wikilinks]]` |
| **Move file** | Same eval pattern | Bash `mv` + check references |
| **Vault stats** | `obsidian tags counts` via Bash | `Glob '**/*.md'` + `wc -l` via Bash |
| **Broken links** | `obsidian unresolved` via Bash | Grep for `[[` + resolve each |
| **Version diff** | `obsidian diff file="..." from=N to=N` via Bash | — (not available) |
| **Note info** | `obsidian read` + parse | `Read` + `Glob` |
| **Delete note** | `obsidian eval "await app.vault.trash(...)"` | Bash `rm` (check inbound links first) |

### qmd search probe (optional)

After the I/O tier probe, optionally probe for qmd semantic search:

```bash
wiki_qmd_probe "${VAULT_PATH}"
echo "qmd: $WIKI_QMD_AVAILABLE"
```

qmd is a **search augmentation**, not an I/O tier. It does not affect which backend (CLI/filetool) is used for reads and writes. When `WIKI_QMD_AVAILABLE` is `"true"`, skills use `wiki_qmd_search` for content discovery instead of keyword search. When `"false"`, skills use the existing search path (Obsidian CLI search or Grep).

**Zero-result fallback:** If `qmd query` returns no results for a given query, fall back to existing search (Obsidian search/Grep) for that query. Report once: `(qmd returned no results, falling back to keyword search)`.

**Metadata queries:** qmd searches document content. For frontmatter/tag-specific lookups (e.g. "all pages with `wiki-source: claude-code`"), continue using Obsidian CLI search or Grep regardless of qmd availability.

### CLI context management pattern

When using CLI (Tier 1), prefer piped output over loading full content:

```bash
# Read only frontmatter (avoids loading full note into context)
obsidian read path="long-page.md" | sed -n '/^---$/,/^---$/p'

# Count search results before reading them
obsidian search query="wiki-source:" | wc -l

# Read first 50 lines of a long page
obsidian read path="long-page.md" | head -50
```

This is the primary advantage of the CLI tier: you control how much content enters the context window.

## Index management

If `paths.index` is non-empty, every operation that creates or updates a `knowledge` or `source-summary` page must also update the index's managed block. Session logs are **never** listed in the index — they belong in the wiki log.

**Managed block markers**:

```
<!-- llm-wiki:index:start -->
...rewritable content...
<!-- llm-wiki:index:end -->
```

**Update algorithm** (deterministic — same inputs → same block):

1. Read `{VAULT_PATH}/{paths.index}`. If the file doesn't exist, create it with just the managed block (no other content).
2. Locate the markers. If either marker is missing, **append** a fresh block to the end of the file preceded by a `---` separator. Do not insert into the middle of existing content.
3. Gather all wiki-sourced pages by reading frontmatter across the vault:
   - **CLI**: `obsidian search query="wiki-source:" limit=200` via Bash, piped to keep only the matched paths (§CLI context management pattern). Then read all frontmatter in a single batched call: `for f in {matched paths}; do echo "== $f"; sed -n '/^---$/,/^---$/p' "{VAULT_PATH}/$f"; done`.
   - **File tools**: `Grep -l "^wiki-source:" {VAULT_PATH}/**/*.md`, then `Read` the frontmatter of each match.
   - Keep only pages where `type` is `knowledge` or `source-summary` (exclude `session-log`, `system`, `enrichment`).
4. Group by `type`, then by `domain` (alphabetical). Within each group, sort by title alphabetical.
5. For each page, derive a one-line summary:
   - `knowledge` → first non-empty paragraph after the frontmatter (trim to ~100 chars, single-line).
   - `source-summary` → first bullet under `## Key Claims` (trim to ~100 chars).
6. Rewrite **only** the content between markers. Preserve the markers verbatim. Do not touch anything outside.

**Content format inside the block**:

```
## Wiki Index

> Auto-maintained by llm-wiki. The block between the `llm-wiki:index:start` and `llm-wiki:index:end` markers is regenerated on every wiki operation. Edits inside will be overwritten; edits outside the markers are preserved.

### Knowledge

**<domain>**
- [[<page-title>]] — <summary>

### Sources

**<domain>**
- [[<page-title>]] — <summary>
```

If either group is empty, emit the heading with an `_(none yet)_` line so the structure is stable.

**Tool choice**: Use `Read` to get the current file, compute the new block in memory, then `Write` the full file (preferred) or `Edit` the marker-bounded substring.

**Rule**: Never update the index inside a transaction that also touches the target page. Update the target page first, confirm it landed, then update the index. This way a half-completed operation can be re-run safely (the index-rebuild is idempotent).

## Protected paths

If `folders.protected` is non-empty, every write, move, or delete operation must first verify the planned target path does NOT begin with any entry in the list (after normalizing both target and entries to vault-relative form — strip `{VAULT_PATH}` prefix if present, collapse `//`).

If a planned write target falls inside a protected path, abort with:

```
Refusing to modify `{path}` — listed in `folders.protected`. Update the schema via the wiki-configure skill (Claude: /llm-wiki:wiki-configure) to allow this folder, or pick a different destination.
```

**Applies to**: `wiki-capture` (session log, knowledge pages, enrichments), `wiki-ingest` (source summary, knowledge pages), `wiki-query` (filing an answer back as a knowledge page, index update, wiki log), `wiki-lint --fix` (orphan cross-links, MOC updates, index rebuild). Each skill's workflow points to this section.

**Archive exemption**: the `wiki-ingest` archive move INTO `{paths.archive_sources}` is always allowed, even when that folder appears in `folders.protected` — receiving archived sources is that folder's purpose (and it is a default protection candidate in wiki-configure). Protection still governs everything else about it: never overwrite or edit an existing archived file (on filename collision, suffix the incoming file, e.g. `name (2).md`), and never write anything there other than the source being archived.

**Reads are never blocked.** Skills may freely read protected files (e.g. copying template content into a new page) but must not modify the originals.

**Index exemption**: index management is only permitted when `{paths.index}` itself resolves outside protected paths. If the index lives inside a protected folder, skip index operations silently (same behavior as `paths.index: ""`).

## Writing the wiki log

Append entries to `{VAULT_PATH}/{paths.wiki_log}` in this format:

```
## [YYYY-MM-DD] <operation> | <subject>
- <action>: [[link-to-affected-page]] (description)
```

Operations: `capture`, `ingest`, `query`, `lint`, `configure`.

## Project mapping

The `Project Mapping` section of the schema describes the user's project sub-structure convention (e.g. Work/Personal split, client-based, flat). Use fuzzy matching:

- CWD basename matches a folder name (case-insensitive)
- Git remote URL hints at client/org when present
- If no match → ask user, or file under `{folders.notes}` if configured, otherwise under `{folders.projects}/misc/`
