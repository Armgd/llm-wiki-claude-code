#!/bin/bash
# wiki-inbox-nudge.sh — PostToolUse hook (fires once per session)
# Reads the vault path (line 1) and optional vault-relative schema path
# (line 2, default _System/wiki-schema.md) from ~/.config/llm-wiki/vault,
# then inbox_threshold + folders.inbox from the schema. Exits silently if
# anything's missing (plugin works fine without this nudge).
#
# Output modes:
#   --json  Claude Code hook JSON (hookSpecificOutput.additionalContext) —
#           plain stdout from a PostToolUse hook is only shown in
#           transcript mode; additionalContext is what reaches the model.
#   (none)  plain text — OpenCode/Pi adapters surface stdout themselves.

VAULT_FILE="$HOME/.config/llm-wiki/vault"

# Config must exist. Bail before doing any per-session work.
[ -f "$VAULT_FILE" ] || exit 0

format="text"
[ "${1:-}" = "--json" ] && format="json"

# Scope the nudge flag per session so concurrent Claude sessions each
# get their own nudge, and a fresh session after cleanup starts clean.
input=$(cat 2>/dev/null || echo '{}')
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && session_id="pid-$PPID"

NUDGE_FLAG="/tmp/wiki-inbox-nudged.${session_id}"

# Only fire once per session.
[ -f "$NUDGE_FLAG" ] && exit 0
touch "$NUDGE_FLAG"

# Trim leading/trailing whitespace ONLY — vault paths may contain spaces.
VAULT_PATH=$(head -n1 "$VAULT_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
[ -z "$VAULT_PATH" ] && exit 0

SCHEMA_REL=$(sed -n '2p' "$VAULT_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
[ -z "$SCHEMA_REL" ] && SCHEMA_REL="_System/wiki-schema.md"

SCHEMA="$VAULT_PATH/$SCHEMA_REL"
[ -f "$SCHEMA" ] || exit 0

# Bail if schema still has unfilled placeholders.
grep -q '{{' "$SCHEMA" && exit 0

# Extract folders.inbox (handles indented YAML-ish bullet list).
# Uses POSIX character classes — macOS sed doesn't support \s.
INBOX_FOLDER=$(grep -E '^[[:space:]]*-[[:space:]]*inbox:[[:space:]]*"' "$SCHEMA" | head -n1 | sed -E 's/.*inbox:[[:space:]]*"([^"]*)".*/\1/')
[ -z "$INBOX_FOLDER" ] && exit 0

# Extract inbox_threshold (default 5).
THRESHOLD=$(grep -E '^[[:space:]]*-[[:space:]]*inbox_threshold:' "$SCHEMA" | head -n1 | sed -E 's/.*inbox_threshold:[[:space:]]*([0-9]+).*/\1/')
[ -z "$THRESHOLD" ] && THRESHOLD=5

INBOX_PATH="$VAULT_PATH/$INBOX_FOLDER"
[ -d "$INBOX_PATH" ] || exit 0

count=$(find "$INBOX_PATH" -maxdepth 1 -name "*.md" -not -name ".*" | wc -l | tr -d ' ')
if [ "$count" -gt "$THRESHOLD" ]; then
  msg="[wiki] $count items in Obsidian inbox await processing. Run the wiki-ingest skill when ready."
  if [ "$format" = "json" ]; then
    if command -v jq >/dev/null 2>&1; then
      printf '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": %s}}\n' \
        "$(printf '%s' "$msg" | jq -Rs .)"
    fi
  else
    echo "$msg"
  fi
fi
