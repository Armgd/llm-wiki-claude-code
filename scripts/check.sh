#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
jq -e . .claude-plugin/plugin.json >/dev/null; echo "✓ manifest"
jq -e . hooks/hooks.json >/dev/null; echo "✓ hooks.json"
jq -e . eval/evals.json eval/lib/prompt-template-local.json >/dev/null; echo "✓ eval json"
jq -e . wiring/antigravity/wiki-hooks.json >/dev/null; echo "✓ wiring json"
bash -n scripts/sync-skills.sh scripts/test-sync-skills.sh hooks/scripts/*.sh shared/scripts/wiki-io.sh wiring/antigravity/wiki-hook-adapter.sh; echo "✓ bash syntax"
bash scripts/test-sync-skills.sh >/dev/null; echo "✓ sync-skills test"
bash scripts/sync-skills.sh --check >/dev/null; echo "✓ skills in sync"
node --check wiring/opencode/wiki-plugin.js; echo "✓ opencode plugin"
# Pi extension is TypeScript — syntax-check when node can strip types (>=22.6).
ts_probe="$(mktemp -t wiki-ts-probe).ts"
echo 'const probe: number = 1;' > "$ts_probe"
if node --experimental-strip-types --check "$ts_probe" >/dev/null 2>&1; then
  node --experimental-strip-types --check wiring/pi/wiki-extension.ts >/dev/null 2>&1 \
    || { echo "✗ pi extension syntax"; rm -f "$ts_probe"; exit 1; }
  echo "✓ pi extension"
else
  echo "- pi extension check skipped (node without type stripping)"
fi
rm -f "$ts_probe"
if grep -rqn 'CLAUDE_PLUGIN_ROOT' .agents/skills shared; then echo "✗ CLAUDE_PLUGIN_ROOT leak"; exit 1; fi
echo "✓ no plugin-root leakage"
echo "ALL CHECKS PASS"
