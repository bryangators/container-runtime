---
name: recap
description: End a session of the container-runtime learning project and record where things stand. Use when Bryan types /recap or says he is done for today.
---

# /recap

Leave the project so that a fresh session can resume in under a minute.

## Steps

1. Ask Bryan to say, in two sentences, what he learned today. Correct anything wrong.
2. Update `docs/PROGRESS.md`:
   - **Now**: milestone, lesson, and a concrete next step ("3.2: find where clone flags
     go in os/exec; hostname change not yet working").
   - **Milestones** table: status changes only via `/checkpoint`, except "in progress".
   - **Open questions**: add anything he got wrong, skipped, needed rung 4 for, or asked
     that was deferred. Remove items that are now clearly understood.
   - **Session log**: one or two lines, dated, newest first.
3. If the working tree has changes, remind him to commit. Suggest a message; he runs it.
4. If the VM is running and he is finished for the day, mention `make vm-down`.
5. Finish with one question for him to think about before next time, related to the next
   lesson.

Keep the recap itself short: he is at the end of a session.
