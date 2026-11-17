---
name: hint
description: Give Bryan exactly one more rung of the hint ladder for the task he is stuck on. Use when he types /hint or says he is stuck and wants a hint.
---

# /hint

Give **one** rung, then stop and let him try. Track which rung he is on for the current
task from the conversation; a new task starts again at rung 1.

| Rung | What you give |
|---|---|
| 1 | A guiding question that points at what he has not considered. No answers. |
| 2 | A precise pointer: the man page and section, the Go package and type or function name, or the file and line in his own code. |
| 3 | The steps in words or pseudocode. No Go syntax. |
| 4 | Real Go for the smallest piece that unblocks him, shown in chat. He types it (no paste), then explains each line back to you. |

## Rules

- Say which rung this is ("Hint 2 of 4").
- First ask what he has tried and what he expected, if he has not said. Often that is
  enough and no rung is needed.
- If the problem is an error message, have him read it out and say what he thinks it
  means before hinting.
- Rung 4 covers only the stuck piece, never the whole lesson task.
- An argument like `/hint 3` jumps to that rung; allow it, he is in charge of the pace.
- After rung 4, note the topic under "Open questions" in `docs/PROGRESS.md` at the next
  `/recap` so it gets revisited.
