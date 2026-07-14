#!/usr/bin/env bash
# wiki-io.sh — Shared I/O helper for llm-wiki skills
#
# Usage (from SKILL.md Bash steps):
#   source "$SKILL_DIR/scripts/wiki-io.sh"   # SKILL_DIR = abs path of the skill dir
#   wiki_io_probe "${VAULT_PATH}"
#   echo "$WIKI_IO_BACKEND"   # "cli" | "filetool"
#
# After sourcing and probing, use the wiki_cli_* wrappers when
# WIKI_IO_BACKEND="cli". For "filetool", the LLM uses its file tools
# (Read/Write/Edit/Grep/Glob) directly on the vault.
#
# NOTE: No `set -euo pipefail` here. This file is sourced, not executed.
# Strict mode would kill the calling shell when CLI wrappers return
# non-zero on empty results (e.g. search with no matches).

# ---------------------------------------------------------------------------
# Private probe helpers
# ---------------------------------------------------------------------------

# _probe_cli: returns 0 if the Obsidian CLI is available and responsive.
_probe_cli() {
  if ! command -v obsidian &>/dev/null; then
    return 1
  fi
  # Smoke test: `obsidian help` must succeed (the CLI talks to the running
  # desktop app; a failure here means the CLI tier is unusable right now).
  obsidian help &>/dev/null || return 1
  return 0
}

# _probe_headless: returns 0 if the 'ob' binary (Obsidian Headless) is installed.
# Headless is a sync service (keeps vault files in sync via Obsidian Sync),
# NOT an I/O backend. It requires an Obsidian account + ob login.
# This probe is used by wiki-configure to record availability in the schema;
# it does NOT influence the I/O tier selection at runtime.
_probe_headless() {
  if ! command -v ob &>/dev/null; then
    return 1
  fi
  return 0
}

# _probe_qmd: returns 0 if the 'qmd' binary is installed and the vault
# is registered as a qmd collection.
#
# qmd 2.1.0+ omits the filesystem path from `collection list` output
# (shows only "name (qmd://name/)"). The absolute path is exposed by
# `collection show <name>` as a "Path:" line. We enumerate collection
# names from list, then query show for each until one matches the vault.
_probe_qmd() {
  local vault_path="${1:?}"
  command -v qmd &>/dev/null || return 1

  local names
  names=$(qmd collection list 2>/dev/null \
    | grep -oE '^[A-Za-z0-9_.-]+ \(qmd://' \
    | awk '{print $1}')
  [ -z "$names" ] && return 1

  local name
  while IFS= read -r name; do
    qmd collection show "$name" 2>/dev/null \
      | grep -qE "^[[:space:]]*Path:[[:space:]]+${vault_path}[[:space:]]*$" \
      && return 0
  done <<< "$names"
  return 1
}

# ---------------------------------------------------------------------------
# Main probe — call once at skill start
# ---------------------------------------------------------------------------

# wiki_io_probe <vault_path>
#   Detects the best available I/O backend and exports:
#     WIKI_IO_BACKEND  — "cli" | "filetool"
#     WIKI_IO_CLI_PATH — absolute path to obsidian binary, or ""
wiki_io_probe() {
  local vault_path="${1:?wiki_io_probe requires vault_path as first argument}"

  if _probe_cli; then
    export WIKI_IO_BACKEND="cli"
    export WIKI_IO_CLI_PATH
    WIKI_IO_CLI_PATH="$(command -v obsidian)"
  else
    export WIKI_IO_BACKEND="filetool"
    export WIKI_IO_CLI_PATH=""
  fi
}

# ---------------------------------------------------------------------------
# qmd probe — optional search augmentation (not an I/O tier)
# ---------------------------------------------------------------------------

# wiki_qmd_probe <vault_path>
#   Detects whether qmd is installed and the vault is registered as a
#   collection. Exports WIKI_QMD_AVAILABLE ("true" or "false").
#   Call AFTER wiki_io_probe. qmd availability does not affect the I/O
#   tier — it only determines whether skills use qmd for content search.
wiki_qmd_probe() {
  local vault_path="${1:?wiki_qmd_probe requires vault_path as first argument}"

  if _probe_qmd "$vault_path"; then
    export WIKI_QMD_AVAILABLE="true"
  else
    export WIKI_QMD_AVAILABLE="false"
  fi
}

# ---------------------------------------------------------------------------
# Convenience wrappers (CLI tier only — check WIKI_IO_BACKEND first)
# All write to stdout; stderr is suppressed.
# ---------------------------------------------------------------------------

# wiki_cli_read <path> [max_lines]
#   Read a note. Optionally limit output to max_lines lines.
wiki_cli_read() {
  local note_path="${1:?wiki_cli_read requires path}"
  local max_lines="${2:-}"

  if [[ -n "$max_lines" ]]; then
    obsidian read path="$note_path" 2>/dev/null | head -n "$max_lines"
  else
    obsidian read path="$note_path" 2>/dev/null
  fi
}

# wiki_cli_search <query> [limit]
#   Full-text search across the vault. Default limit: 20.
wiki_cli_search() {
  local query="${1:?wiki_cli_search requires query}"
  local limit="${2:-20}"

  obsidian search query="$query" limit="$limit" 2>/dev/null
}

# wiki_cli_create <path> <content> [template]
#   Create a new note. Pass a template name as the third argument to apply one.
wiki_cli_create() {
  local note_path="${1:?wiki_cli_create requires path}"
  local content="${2:?wiki_cli_create requires content}"
  local template="${3:-}"

  if [[ -n "$template" ]]; then
    obsidian create path="$note_path" content="$content" template="$template" silent 2>/dev/null
  else
    obsidian create path="$note_path" content="$content" silent 2>/dev/null
  fi
}

# wiki_cli_append <path> <content>
#   Append content to an existing note.
wiki_cli_append() {
  local note_path="${1:?wiki_cli_append requires path}"
  local content="${2:?wiki_cli_append requires content}"

  obsidian append path="$note_path" content="$content" 2>/dev/null
}

# wiki_cli_move <old_path> <new_path>
#   Rename/move a note using the Obsidian file manager so links are updated.
#   Returns 1 on failure.
wiki_cli_move() {
  local old_path="${1:?wiki_cli_move requires old_path}"
  local new_path="${2:?wiki_cli_move requires new_path}"

  # Encode paths as JSON string literals via jq so quotes, backslashes, control
  # chars, and UTF-8 are escaped correctly and portably. JSON string syntax is
  # valid JS string syntax, and jq emits the surrounding double quotes. This
  # avoids fragile shell backslash handling that differs across bash versions.
  local old_js new_js
  old_js=$(printf '%s' "$old_path" | jq -Rs .) || return 1
  new_js=$(printf '%s' "$new_path" | jq -Rs .) || return 1

  obsidian eval "await app.fileManager.renameFile(app.vault.getAbstractFileByPath($old_js), $new_js)" 2>/dev/null \
    || return 1
}

# wiki_cli_property_read <path> <name>
#   Read a single frontmatter property value.
wiki_cli_property_read() {
  local note_path="${1:?wiki_cli_property_read requires path}"
  local prop_name="${2:?wiki_cli_property_read requires name}"

  obsidian property:read path="$note_path" name="$prop_name" 2>/dev/null
}

# wiki_cli_property_set <path> <name> <value>
#   Set a frontmatter property.
wiki_cli_property_set() {
  local note_path="${1:?wiki_cli_property_set requires path}"
  local prop_name="${2:?wiki_cli_property_set requires name}"
  local prop_value="${3:?wiki_cli_property_set requires value}"

  obsidian property:set path="$note_path" name="$prop_name" value="$prop_value" 2>/dev/null
}

# wiki_cli_unresolved
#   List all unresolved (dangling) links in the vault.
wiki_cli_unresolved() {
  obsidian unresolved 2>/dev/null
}

# ---------------------------------------------------------------------------
# qmd wrappers (search augmentation — check WIKI_QMD_AVAILABLE first)
# ---------------------------------------------------------------------------

# wiki_qmd_search <query> [limit]
#   Hybrid search: BM25 + vector + LLM re-ranking. Returns ranked results
#   with docid, score, filepath, and context snippet (--files format).
wiki_qmd_search() {
  local query="${1:?wiki_qmd_search requires query}"
  local limit="${2:-10}"

  qmd query "$query" -n "$limit" --files 2>/dev/null
}

# wiki_qmd_get <path> [max_lines]
#   Retrieve a document by path via qmd. Optionally limit output lines.
wiki_qmd_get() {
  local doc_path="${1:?wiki_qmd_get requires path}"
  local max_lines="${2:-}"

  if [[ -n "$max_lines" ]]; then
    qmd get "$doc_path" 2>/dev/null | head -n "$max_lines"
  else
    qmd get "$doc_path" 2>/dev/null
  fi
}
