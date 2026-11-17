#!/usr/bin/env bash
# SessionStart hook: stdout is added to Claude's context, so every session
# begins knowing where the last one stopped.
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
progress="$root/docs/PROGRESS.md"

echo "=== container-runtime: current progress (docs/PROGRESS.md) ==="
if [ -r "$progress" ]; then
  cat "$progress"
else
  echo "docs/PROGRESS.md is missing."
fi
echo "=== end progress ==="
if [ -e "$root/.claude/allow-go-edits" ]; then
  echo "NOTE: .claude/allow-go-edits exists, so the Go edit block is currently lifted. Mention this to Bryan."
fi
echo "Coaching rules are in CLAUDE.md. Suggest /lesson to continue."
