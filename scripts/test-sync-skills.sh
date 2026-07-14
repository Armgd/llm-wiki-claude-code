#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

# Always leave the tree in sync, even when an assertion fails mid-run.
trap 'bash scripts/sync-skills.sh >/dev/null' EXIT

# 1. sync populates every skill (iterate the actual shared payload, so new
#    shared files are covered automatically)
bash scripts/sync-skills.sh
for s in .agents/skills/*/; do
  for src in shared/references/* shared/scripts/*; do
    [ -e "$src" ] || continue
    diff -q "$src" "$s${src#shared/}" >/dev/null
  done
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
