#!/bin/bash
# wiki-stop.sh — Stop hook (fires every time the agent finishes a turn,
# NOT once per session). Emits a once-per-session reminder to run
# wiki-capture when the session has tracked file changes.
#
# /tmp state cleanup lives in wiki-cleanup.sh (SessionEnd) — never here,
# otherwise the change manifest would be wiped after every turn and
# wiki-capture would only ever see the last turn's writes.
#
# Output modes:
#   --json  Claude Code hook JSON ({"systemMessage": ...}) — plain stdout
#           from a Stop hook is only shown in transcript mode, so JSON is
#           required for the reminder to actually surface.
#   (none)  plain text — OpenCode/Pi adapters surface stdout themselves.

[ -f "$HOME/.config/llm-wiki/vault" ] || exit 0

format="text"
[ "${1:-}" = "--json" ] && format="json"

input=$(cat 2>/dev/null || echo '{}')
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && session_id="pid-$PPID"

manifest="/tmp/wiki-session-changes.${session_id}"
flag="/tmp/wiki-stop-reminded.${session_id}"

# Only remind when this session actually tracked changes, and only once.
[ -s "$manifest" ] || exit 0
[ -f "$flag" ] && exit 0
touch "$flag"

count=$(wc -l < "$manifest" | tr -d ' ')
msg="[wiki] $count file change(s) tracked this session. Run the wiki-capture skill (Claude: /llm-wiki:wiki-capture) before wrapping up if noteworthy work was done."

if [ "$format" = "json" ]; then
  if command -v jq >/dev/null 2>&1; then
    printf '{"systemMessage": %s}\n' "$(printf '%s' "$msg" | jq -Rs .)"
  fi
else
  echo "$msg"
fi
