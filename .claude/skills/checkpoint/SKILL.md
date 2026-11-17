---
name: checkpoint
description: Milestone gate for the container-runtime learning project - acceptance check, journal critique and quiz. Use when Bryan types /checkpoint or says a milestone is finished.
---

# /checkpoint

A milestone is done only when all three gates pass. Be honest; a soft pass defeats the
purpose.

## Gate 1: it works

1. Read the milestone's **Acceptance** line in `docs/SPEC.md`.
2. Have Bryan run it in the VM (`make vm-run ARGS="..."`, `make vm-test`) and paste the
   output. Check for leftovers too where relevant (`mount`, `/sys/fs/cgroup`, `ip link`).
3. If it fails, stop here and go back to the lesson.

## Gate 2: he can explain it

1. Check `journal/M<N>-*.md` exists. If not, ask him to write it using
   `journal/README.md` and the milestone's **Explain-back** prompt, then stop.
2. Launch the `explain-critic` agent with the journal file path, the milestone section of
   the spec, and the relevant source files.
3. Relay the critique: what is correct, what is missing, what is wrong. He revises the
   entry himself. Repeat until there are no errors of fact; small gaps can go to
   "Still fuzzy".

## Gate 3: quiz

Ask five questions, one at a time, waiting for each answer:

- 2 on the kernel mechanism (what the syscall or kernel object does)
- 1 on his own code (why a specific line is where it is)
- 1 "what would happen if..." prediction he can then verify in the VM
- 1 tying it to podman behaviour

Free-text answers, no multiple choice. Pass is 4 of 5 with no misconception left
standing. For a wrong answer, explain, and add it to "Open questions".

## On pass

- Update `docs/PROGRESS.md`: mark the milestone done, set the next milestone and lesson.
- Suggest he commits (`git add -A && git commit`) and pushes.
- At the Liz Rice checkpoint, also run the scope decision described in the spec and
  record the outcome in `docs/SPEC.md`.

## On fail

Say which gate failed and what to do next. Do not advance the milestone.
