#!/usr/bin/env bash
# wiki-hook-adapter.sh <notify|nudge|stop> — Antigravity CLI (agy) → llm-wiki bridge.
# Translates agy's hook payload (toolCall.name / toolCall.args.*) into the
# Claude-shaped stdin the canonical scripts under hooks/scripts/ expect.
#
# Verified against public docs: toolCall.name, toolCall.args, top-level
# session_id, tool names write_to_file / replace_file_content /
# multi_replace_file_content. The file-path arg name inside toolCall.args is
# NOT publicly documented — this script tries the plausible candidates and
# exits silently when none match. Inspect a real payload (log stdin to a file
# from a throwaway hook) before relying on the change manifest.
set -euo pipefail
mode="${1:?usage: wiki-hook-adapter.sh <notify|nudge|stop>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null || echo '{}')

session_id=$(echo "$input" | jq -r '.session_id // .sessionId // empty')
[ -z "$session_id" ] && session_id="pid-$PPID"

case "$mode" in
  notify)
    tool=$(echo "$input" | jq -r '.toolCall.name // empty')
    case "$tool" in
      write_to_file) mapped="Write" ;;
      replace_file_content|multi_replace_file_content) mapped="Edit" ;;
      *) exit 0 ;;
    esac
    file=$(echo "$input" | jq -r '.toolCall.args | (.TargetFile // .AbsolutePath // .file_path // .path // empty)' 2>/dev/null)
    [ -z "$file" ] && exit 0
    jq -n --arg t "$mapped" --arg f "$file" --arg s "$session_id" \
      '{tool_name: $t, tool_input: {file_path: $f}, session_id: $s}' \
      | bash "$ROOT/hooks/scripts/wiki-notify.sh"
    ;;
  nudge)
    jq -n --arg s "$session_id" '{session_id: $s}' \
      | bash "$ROOT/hooks/scripts/wiki-inbox-nudge.sh"
    ;;
  stop)
    jq -n --arg s "$session_id" '{session_id: $s}' \
      | bash "$ROOT/hooks/scripts/wiki-stop.sh"
    ;;
esac
