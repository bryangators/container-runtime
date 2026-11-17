# Journal

One file per milestone, written by Bryan in his own words: `journal/M2-processes.md`,
`journal/M3-uts-namespace.md`, and so on.

Claude does not write or edit these files (a hook blocks it). At `/checkpoint` the
`explain-critic` agent reads the entry and points out gaps; Bryan revises it himself.

## What an entry contains

1. **What I built**: two or three sentences.
2. **How it works**: the mechanism, as if explaining to a colleague who uses podman but
   has never looked underneath. Name the syscalls and kernel objects involved.
3. **What surprised me**: predictions that turned out wrong, and why.
4. **Where this shows up in podman**: a flag, an error message or a behaviour this explains.
5. **Still fuzzy**: what I could not explain if asked.

Aim for something you could read out at a whiteboard in three minutes.
