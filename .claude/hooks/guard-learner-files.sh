#!/usr/bin/env bash
# PreToolUse hook for Edit|Write|NotebookEdit.
# Blocks Claude from writing the files the learner is meant to write himself:
#   - Go source, go.mod, go.sum
#   - journal entries (everything in journal/ except README.md)
#   - the override file itself
# Exit 2 = block the tool call; stderr is shown to Claude as the reason.
# Override: the learner creates .claude/allow-go-edits (gitignored) to allow Go edits.
#
# This is a guardrail against habit, not a security boundary: a Bash redirect would
# bypass it. CLAUDE.md forbids that.
set -euo pipefail

input=$(cat)
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[ -z "$path" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
case "$path" in
  /*) ;;
  *) path="$root/$path" ;;
esac
path=$(realpath -m -- "$path")

# Only police files inside this project.
case "$path" in
  "$root"/*) rel="${path#"$root"/}" ;;
  *) exit 0 ;;
esac

deny() {
  echo "BLOCKED by .claude/hooks/guard-learner-files.sh: $1" >&2
  exit 2
}

case "$rel" in
  .claude/allow-go-edits)
    deny "only Bryan creates the override file. Ask him to run: touch .claude/allow-go-edits"
    ;;
  journal/README.md)
    exit 0
    ;;
  journal/*)
    deny "journal entries are Bryan's own explanations. Do not write or edit them. Give feedback in chat (or via the explain-critic agent) and let him revise."
    ;;
  *.go | go.mod | go.sum | */go.mod | */go.sum)
    if [ -e "$root/.claude/allow-go-edits" ]; then
      exit 0
    fi
    deny "Bryan types all Go in this project ($rel). Coach instead: use the hint ladder in CLAUDE.md and show code in chat only at rung 4. Do not work around this with Bash."
    ;;
esac

exit 0
