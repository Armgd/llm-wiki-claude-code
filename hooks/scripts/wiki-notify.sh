#!/bin/bash
# wiki-notify.sh — PostToolUse hook for Write/Edit
# Logs modified file paths to a per-session manifest for /wiki-capture.
#
# Short-circuits when llm-wiki isn't configured for this user (so it's a
# no-op in unrelated sessions on the same machine). Manifest path is
# scoped per Claude session to avoid cross-contamination when multiple
# sessions run concurrently.

# Bail immediately if llm-wiki isn't configured on this host.
[ -f "$HOME/.config/llm-wiki/vault" ] || exit 0

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

if [ "$tool_name" != "Write" ] && [ "$tool_name" != "Edit" ]; then
  exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

# Scope the manifest per session. Fall back to PPID if session_id isn't
# provided (older Claude Code versions); that still isolates per shell.
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && session_id="pid-$PPID"

manifest="/tmp/wiki-session-changes.${session_id}"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $file_path" >> "$manifest"
