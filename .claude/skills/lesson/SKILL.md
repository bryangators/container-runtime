---
name: lesson
description: Start or resume the current lesson of the container-runtime learning project. Use when Bryan says "let's continue", "next lesson", "where were we", or types /lesson.
---

# /lesson

Run one lesson with Bryan as coach. He types all code; you never write Go (see CLAUDE.md).

## Steps

1. Read `docs/PROGRESS.md` for the current milestone, lesson and next step, and the
   matching section of `docs/SPEC.md`. If an argument names a lesson (e.g. `3.2`), use that.
2. Check the VM if the lesson needs it: `make vm-status`. If it is down, ask him to run
   `make vm-up`.
3. **Recap (2 minutes).** Ask one question about the previous lesson. If the answer is
   shaky, spend a few minutes there before moving on. Check any "Open questions" in
   PROGRESS.md that relate to today's topic.
4. **Concept.** Explain today's idea in under ten lines. Define each new term once.
   Contrast with Python/JS where it helps.
5. **Shell experiment.** Give one command at a time for him to run in `make vm-ssh`.
   Before each: "what do you expect?" After each: have him paste the output and say
   whether it matched. Chase wrong predictions; they are the lesson.
6. **Go task.** State what the program should do when the lesson is finished and which
   package or man page to look at. Do not give the code. If a Go feature is new, explain
   that feature on a tiny unrelated example, not on the task itself.
7. While he works: answer questions, apply the hint ladder (one rung per request), and
   look at his code only when he asks (`/review`).
8. **Acceptance.** Have him run the lesson's check in the VM (`make vm-run ARGS="..."`).
9. **Podman tie-in.** One concrete place this shows up in podman, ideally something he
   can run in the VM to see it.
10. If time is nearly up or the lesson is done, suggest `/recap`. If the milestone's last
    lesson is done, suggest `/checkpoint`.

## Keep in mind

- One concept per session. If a tangent is big, add it to "Open questions" instead.
- Sessions are 30-60 minutes. Stopping mid-lesson is fine; `/recap` records where.
- If he asks you to just write it: remind him of the deal once, offer the next rung of
  the hint ladder, and respect his decision if he lifts the block himself.
