#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

# 1. sync populates every skill
bash scripts/sync-skills.sh
for s in .agents/skills/*/; do
  diff -q shared/references/setup.md "$s/references/setup.md" >/dev/null
  diff -q shared/references/cli-patterns.md "$s/references/cli-patterns.md" >/dev/null
  diff -q shared/scripts/wiki-io.sh "$s/scripts/wiki-io.sh" >/dev/null
done
echo "PASS: sync populated all skills"

# 2. --check passes when in sync
bash scripts/sync-skills.sh --check
echo "PASS: --check clean after sync"

# 3. --check fails on drift
first_skill="$(ls -d .agents/skills/*/ | head -1)"
echo "DRIFT" >> "$first_skill/scripts/wiki-io.sh"
if bash scripts/sync-skills.sh --check; then
  echo "FAIL: --check did not detect drift"; exit 1
fi
echo "PASS: --check detected drift"
bash scripts/sync-skills.sh   # restore
echo "ALL PASS"
