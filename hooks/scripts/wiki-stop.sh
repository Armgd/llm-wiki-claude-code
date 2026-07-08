#!/bin/bash
# wiki-stop.sh — Stop hook
# Reminds Claude to capture session knowledge before ending, and cleans up
# this session's /tmp state. Silent when llm-wiki isn't configured.

[ -f "$HOME/.config/llm-wiki/vault" ] || exit 0

input=$(cat 2>/dev/null || echo '{}')
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && session_id="pid-$PPID"

manifest="/tmp/wiki-session-changes.${session_id}"
nudge_flag="/tmp/wiki-inbox-nudged.${session_id}"

if [ -f "$manifest" ]; then
  count=$(wc -l < "$manifest" | tr -d ' ')
  echo "[wiki] Session ending. $count file changes tracked. Review session for wiki-worthy knowledge — run /llm-wiki:wiki-capture if noteworthy work was done."
  rm -f "$manifest"
else
  echo "[wiki] Session ending. Run /llm-wiki:wiki-capture if this session produced noteworthy decisions, findings, or patterns."
fi

rm -f "$nudge_flag"
