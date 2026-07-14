#!/bin/bash
# wiki-cleanup.sh — SessionEnd hook
# Removes this session's /tmp state (change manifest, nudge flag, reminder
# flag). Runs at real session end — Stop fires every turn and must NOT
# clean up, or wiki-capture loses all but the last turn's changes.

[ -f "$HOME/.config/llm-wiki/vault" ] || exit 0

input=$(cat 2>/dev/null || echo '{}')
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && session_id="pid-$PPID"

rm -f "/tmp/wiki-session-changes.${session_id}" \
      "/tmp/wiki-inbox-nudged.${session_id}" \
      "/tmp/wiki-stop-reminded.${session_id}"
