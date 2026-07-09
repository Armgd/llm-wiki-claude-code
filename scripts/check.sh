#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
jq -e . .claude-plugin/plugin.json >/dev/null; echo "✓ manifest"
jq -e . hooks/hooks.json >/dev/null; echo "✓ hooks.json"
jq -e . wiring/codex/hooks.json wiring/gemini/settings.hooks.json >/dev/null; echo "✓ wiring json"
bash -n scripts/sync-skills.sh hooks/scripts/*.sh shared/scripts/wiki-io.sh; echo "✓ bash syntax"
bash scripts/sync-skills.sh --check; echo "✓ skills in sync"
node --check wiring/opencode/wiki-plugin.js; echo "✓ opencode plugin"
if grep -rqn 'CLAUDE_PLUGIN_ROOT' .agents/skills shared; then echo "✗ CLAUDE_PLUGIN_ROOT leak"; exit 1; fi
echo "✓ no plugin-root leakage"
echo "ALL CHECKS PASS"
