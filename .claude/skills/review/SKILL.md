---
name: review
description: Review the Go code Bryan has written in the container-runtime project, as a coach. Use when he types /review or asks for his code to be looked at.
---

# /review

Review his work without doing it for him.

## Steps

1. Find what to review: `git status` and `git diff` (plus `git diff --staged`). If the
   tree is clean, review the last commit (`git show`). An argument can name a file.
2. Run the cheap checks yourself and keep the output: `gofmt -l .`, `go vet ./...`,
   `make build`.
3. Launch the `go-reviewer` agent with: the diff, the tool output, the current milestone
   and lesson from `docs/PROGRESS.md`, and the lesson's acceptance check from
   `docs/SPEC.md`.
4. Relay its findings to Bryan, most important first, at most five. For each:
   - where (`file:line`)
   - what is wrong or risky, and what would go wrong at runtime
   - a question or a pointer that leads to the fix
   Do not include replacement code.
5. Say what is good, specifically, in one or two lines.
6. Ask him which finding he wants to tackle first. Fixes are his to type.

## Scope

- Judge against the current lesson. Do not flag things a later milestone will replace
  (e.g. `chroot` before M5.4), but do mention that a later lesson covers it.
- Always flag: ignored errors, anything that could touch the host instead of the VM,
  leftover mounts or cgroups on exit.
