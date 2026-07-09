#!/usr/bin/env bash
# sync-skills.sh — copy canonical shared/ payload into each skill.
#   (no args)  copy shared/{references,scripts}/* into every .agents/skills/*/
#   --check    exit non-zero if any skill copy differs from canonical
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
shared="$root/shared"
skills_dir="$root/.agents/skills"
check_mode="${1:-}"

drift=0
for skill in "$skills_dir"/*/; do
  for sub in references scripts; do
    for src in "$shared/$sub"/*; do
      [ -e "$src" ] || continue
      dst="$skill$sub/$(basename "$src")"
      if [ "$check_mode" = "--check" ]; then
        if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
          echo "DRIFT: $dst differs from $src"
          drift=1
        fi
      else
        mkdir -p "$skill$sub"
        cp "$src" "$dst"
      fi
    done
  done
done

if [ "$check_mode" = "--check" ]; then
  [ "$drift" -eq 0 ] && echo "sync-skills: all skills in sync"
  exit "$drift"
fi
echo "sync-skills: synced $(ls -d "$skills_dir"/*/ | wc -l | tr -d ' ') skills"
