# Obsidian CLI Patterns

> Referenced by llm-wiki skills when CLI is the active I/O backend. Load this file when you need Obsidian CLI command syntax for reading, writing, searching, or managing notes via the `obsidian` binary.

---

## Prerequisites

- Obsidian desktop app must be running. The CLI controls the running app — if the app is not running, the first CLI command will launch it.
- `obsidian` binary on PATH:
  - macOS: `/usr/local/bin/obsidian`
  - Linux: `~/.local/bin/obsidian`

Verify with:

```bash
which obsidian && obsidian --version
```

---

## Parameter Syntax

| Pattern | Description | Example |
|---|---|---|
| `key="value"` | Parameters use `=` with quoted values | `obsidian create name="My Note" content="Hello"` |
| bare word | Flags are bare words (no value) | `obsidian create name="My Note" silent overwrite` |
| `\n`, `\t` | Multiline content: use escape sequences | `content="Line 1\n\nLine 2"` |
| `file="Note Name"` | Wikilink-style targeting (fuzzy match) | `obsidian read file="Prompt Engineering"` |
| `path="exact/path.md"` | Exact path from vault root | `obsidian read path="03 - Resources/AI/Prompt Engineering.md"` |
| `vault="My Vault"` | Target a specific vault (defaults to most recently focused) | `obsidian search query="foo" vault="Work"` |

---

## Command Reference

### Reading

```bash
# Wikilink-style — fuzzy match by note name
obsidian read file="Note Name"

# Exact path from vault root
obsidian read path="03 - Resources/AI/Prompt Engineering.md"

# Context management — only retrieve the first 30 lines
obsidian read file="Note Name" | head -30
```

### Searching

```bash
# Full-text search with a result limit
obsidian search query="container networking" limit=20

# Count matching results
obsidian search query="wiki-source" | wc -l

# Search by frontmatter field value
obsidian search query="domain: AI" limit=10
```

### Creating

```bash
# Create a note with inline content (silent suppresses confirmation)
obsidian create name="My Page" content="# Title\n\nBody" silent

# Create from a template
obsidian create name="Session Log" template="session-log" silent

# Create or overwrite if already exists
obsidian create name="My Page" content="..." silent overwrite
```

### Appending

```bash
# Append a callout block to an existing note
obsidian append file="My Page" content="\n---\n\n> [!claude] Added 2026-04-16\n> New insight"

# Append to today's daily note
obsidian daily:append content="- Reviewed wiki health"
```

### Properties (Frontmatter)

```bash
# Read a single frontmatter property
obsidian property:read file="My Page" name="wiki-source"

# Set (or create) a frontmatter property
obsidian property:set file="My Page" name="wiki-source" value="claude-code"

# Remove a frontmatter property
obsidian property:remove file="My Page" name="old-field"
```

### Diagnostics

```bash
# List all broken wikilinks in the vault
obsidian unresolved

# List tasks in a specific note
obsidian tasks file="session-log-2026-04-16"

# Show tag frequencies across the vault
obsidian tags counts

# Diff two versions of a note (version numbers from history)
obsidian diff file="My Page" from=1 to=5
```

### Moving (via eval)

Prefer `eval` over shell `mv` because it updates backlinks automatically:

```bash
# Rename/move a file and preserve all backlinks
obsidian eval "await app.fileManager.renameFile(app.vault.getAbstractFileByPath('old/path.md'), 'new/path.md')"
```

> **Caveat:** `eval` executes arbitrary JavaScript inside Obsidian's renderer process. If it fails (e.g. Obsidian Headless does not support eval), fall back to `mv` and then run `obsidian unresolved` to identify and manually relink any broken references.

---

## Context Management Advantages

Piping CLI output lets you extract exactly the lines you need, reducing token usage.

```bash
# Extract only the YAML frontmatter block from a note
obsidian read file="My Page" | sed -n '/^---$/,/^---$/p'

# Count notes that have a specific frontmatter field set
obsidian search query="wiki-source:" | wc -l

# Read only the first 50 lines of a long note
obsidian read path="long-reference.md" | head -50

# List all unique tags from search results
obsidian search query="domain: AI" | grep -oE '#[^ ]+' | sort -u
```
