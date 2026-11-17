# container-runtime

A small container runtime written by hand in Go, to learn how containers work underneath
(processes, namespaces, root filesystems, cgroups, user namespaces, overlayfs, networking)
and to learn Go.

It is a learning project. Do not use it for anything real.

- [`docs/SPEC.md`](docs/SPEC.md): goal, milestones and acceptance checks
- [`docs/PROGRESS.md`](docs/PROGRESS.md): where things stand
- [`journal/`](journal/): explanations of each milestone in my own words

## Running it

The runtime manipulates namespaces, mounts and cgroups, so it only ever runs inside a
disposable Fedora VM (plain QEMU/KVM, no root needed on the host).

```
make vm-up                      # first run downloads a Fedora Cloud image and provisions it
make vm-ssh                     # shell in the VM
make vm-run ARGS="run ls -l"    # sync the repo, build in the VM, run as root
make vm-test                    # go vet + go test in the VM
make vm-reset                   # throw the VM away and start clean
make vm-down
```

Host requirements: Go, QEMU with KVM, `genisoimage`, `rsync`, `jq`.

## How it is built

All Go and all journal entries are typed by me. Claude Code is set up as a coach rather
than an implementer; the configuration is in the repo as a worked example:

| Piece | Where | What it does |
|---|---|---|
| Coaching contract | `CLAUDE.md` | Learner profile, rules, hint ladder, lesson shape |
| Guardrail hook | `.claude/hooks/guard-learner-files.sh` | Blocks Claude from editing Go source and journal entries |
| Session hook | `.claude/hooks/session-context.sh` | Loads `docs/PROGRESS.md` at session start |
| Skills | `.claude/skills/` | `/lesson`, `/hint`, `/review`, `/checkpoint`, `/recap` |
| Subagents | `.claude/agents/` | `go-reviewer`, `explain-critic`, `kernel-researcher` |

Inspired by Liz Rice's talk "Containers From Scratch".
