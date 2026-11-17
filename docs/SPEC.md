# container-runtime: specification

## Goal

Build a small container runtime in Go, by hand, to understand what a container is at the
kernel level and to learn Go along the way.

**Done means:** Bryan can explain, end to end and without notes, what happens between
typing `podman run alpine sh` and getting a shell prompt, and can point to the code he
wrote for each step.

Secondary goal: practise setting up AI tooling (spec, skills, hooks, subagents, progress
tracking) in a form that can be reused at work.

## Non-goals

- Production safety or hardening. This runs only in a throwaway VM.
- Building images (no Containerfile support).
- A daemon, an API, or Kubernetes CRI.
- Anything other than Linux x86_64 with cgroups v2.

## How the work is done

- Bryan types all Go and all journal entries. Claude coaches (see `CLAUDE.md`).
- Each lesson fits a 30-60 minute session and follows the same shape:
  recap → concept → shell experiment (predict first) → Go task → acceptance check →
  podman tie-in.
- A milestone is finished only when `/checkpoint` passes: the acceptance check works in
  the VM, the journal entry survives the `explain-critic` review, and the quiz is passed.
- Namespaces, mounts and cgroups are only ever touched inside the VM.

## The program

A single binary, `container-runtime`, grown one milestone at a time. Its command line
after M6 looks like:

```
container-runtime run [flags] <rootfs> <command> [args...]
```

Flags and subcommands are added only when a milestone needs them. The binary name is
Bryan's to change.

---

## Milestones

### M0 Environment

**Why:** a safe place to break things, and a working edit → build → run loop.

| Lesson | Content |
|---|---|
| 0.1 | Bring up the VM (`make vm-up`, `make vm-ssh`). Look around: `uname -r`, `id`, `ps -ef`, `ls /proc`, `mount \| head`. What is different from the host, what is the same? |
| 0.2 | VS Code Go extension. `go mod init`, a hello-world `main.go`, `make build`, `make vm-run`. What is in a Go binary; why it can be copied to the VM and just run. |

**Acceptance:** `make vm-run` prints a greeting from inside the VM.
**Explain-back:** why are we using a VM rather than a container to develop a container runtime?

### M1 Go warm-up

**Why:** enough Go to read and write the runtime without fighting the language. Each
exercise is something the runtime will need later.

| Lesson | Content | Go ideas |
|---|---|---|
| 1.1 | Print the program's arguments; a `run` subcommand that echoes what it would run | packages, `func main`, `os.Args`, slices, `switch`, `fmt` |
| 1.2 | Read `/proc/self/status` and print the PID and name of the current process | `os.ReadFile`, multiple return values, `if err != nil`, strings |
| 1.3 | Run `ls -l` as a child with stdin/stdout/stderr attached; report its exit code | `os/exec`, structs, pointers, methods, type assertion on errors |
| 1.4 | Move the `/proc` parsing into a function with a table-driven test | functions, `go test`, `testing` package, project layout |

**Acceptance:** `make vm-test` passes; `container-runtime run ls -l` lists files and exits
with the child's exit code.
**Podman tie-in:** podman, crun's cousin runc, Kubernetes and containerd are all Go; this
is the style of code you will read there.
**Explain-back:** how does Go error handling differ from Python exceptions, and what does
a pointer give you that Python hides?

### M2 Processes

**Concept:** a process is created by `fork` (clone the caller) and becomes a different
program by `exec` (replace the caller's program). The parent `wait`s and collects an exit
status. Everything a container runtime does happens between the fork and the exec.

| Lesson | Content |
|---|---|
| 2.1 | Shell: `echo $$`, `ps -o pid,ppid,cmd`, `pstree -p`, `/proc/<pid>/{status,exe,cmdline}`. `exec ls` in a throwaway shell: what happens to the shell? |
| 2.2 | Shell: `strace -f -e trace=clone,clone3,fork,vfork,execve,wait4,exit_group sh -c 'ls'`. Find the fork, the exec and the wait. Then strace your M1 program. |
| 2.3 | Go: make `run` robust: pass through the exit code, forward signals (Ctrl-C reaches the child), handle "command not found". |

**Acceptance:** `container-runtime run sh -c 'exit 7'; echo $?` prints 7. Ctrl-C during
`container-runtime run sleep 100` stops the child and leaves no orphan.
**Podman tie-in:** `podman run` exit codes (125, 126, 127 and the container's own); what
`conmon` is waiting on.
**Explain-back:** walk through what the kernel does, step by step, when a shell runs `ls`.

### M3 UTS namespace

**Concept:** a namespace gives a process its own copy of one kind of global resource. UTS
(hostname) is the simplest one. Namespaces are requested with flags at `clone` time.

| Lesson | Content |
|---|---|
| 3.1 | Shell: `ls -l /proc/$$/ns`. `sudo unshare --uts sh`, change the hostname inside, check outside. Compare the `uts` link inside and outside. `lsns`. |
| 3.2 | Go: start the child in a new UTS namespace. Find where clone flags go in `os/exec`. Run a shell, change the hostname by hand, confirm the host is unaffected. |
| 3.3 | Problem: the runtime should set the hostname *before* the user's command starts, but *after* the namespace exists. Go: the re-exec pattern: `run` starts `/proc/self/exe child ...` in new namespaces; `child` does the setup and then runs the command. |

**Acceptance:** `sudo container-runtime run hostname` prints the container hostname, and
`hostname` on the VM afterwards is unchanged.
**Podman tie-in:** `podman run --hostname`, `--uts=host`.
**Explain-back:** why can't Go just fork and run setup code in the child like C does, and
how does re-executing `/proc/self/exe` get around it?

### M4 PID and mount namespaces

**Concept:** in a new PID namespace the first process is PID 1 and cannot see outside
processes. But `ps` reads `/proc`, which is a mounted filesystem, so it needs its own
mount namespace and a fresh `/proc` too.

| Lesson | Content |
|---|---|
| 4.1 | Shell: `sudo unshare --pid --fork sh`, then `echo $$` and `ps`. Why does `ps` still show everything? Then add `--mount-proc`. Why is `--fork` needed? |
| 4.2 | Go: add the PID namespace flag; confirm PID 1; observe `ps` is still wrong. |
| 4.3 | Shell: mount namespaces and propagation: `findmnt -o TARGET,PROPAGATION`, shared vs private. Go: new mount namespace, make mounts private, mount `/proc` in the child. |
| 4.4 | What PID 1 means: signals, zombies, reaping. Observe what happens when PID 1 exits. |

**Acceptance:** `sudo container-runtime run ps -ef` shows only the container's processes,
and `mount | grep proc` on the VM afterwards shows no leftover mounts.
**Podman tie-in:** `podman run --init`, `--pid=host`, why a container stops when its main
process exits.
**Explain-back:** why does a PID namespace alone not hide other processes from `ps`?

### M5 Root filesystem

**Concept:** a container's files are just a directory tree that becomes the process's `/`.
`chroot` changes where `/` points; `pivot_root` swaps the root mount and lets the old one
be unmounted, which is what real runtimes use.

| Lesson | Content |
|---|---|
| 5.1 | Get a rootfs: `podman export` an Alpine container and untar it. Look inside: it is only files. Shell: `sudo chroot rootfs sh`. |
| 5.2 | Go: `chroot` + `chdir` in the child before running the command; mount `/proc` inside the new root. |
| 5.3 | Escaping a chroot, and why `pivot_root` exists. Shell: do a `pivot_root` by hand inside `unshare --mount`. |
| 5.4 | Go: replace `chroot` with `pivot_root`; unmount the old root. Add minimal `/dev` and `/sys`. |

**Acceptance:** `sudo container-runtime run rootfs cat /etc/os-release` prints Alpine's,
`ls /` inside shows no host files, and the old root is not reachable.
**Podman tie-in:** what an image is on disk; `podman export` / `podman mount`.
**Explain-back:** what is the difference between `chroot` and `pivot_root`, and why does
it matter for isolation?

### M6 cgroups v2

**Concept:** namespaces limit what a process can *see*; cgroups limit what it can *use*.
A cgroup is a directory under `/sys/fs/cgroup`; limits are files; membership is writing a
PID into `cgroup.procs`.

| Lesson | Content |
|---|---|
| 6.1 | Shell: `cat /proc/self/cgroup`, explore `/sys/fs/cgroup`, `cgroup.controllers`, `cgroup.subtree_control`. Create a cgroup by hand, set `pids.max`, move a shell in, hit the limit. |
| 6.2 | Go: create a cgroup for the container, set `pids.max`, add the child, remove the cgroup on exit. |
| 6.3 | Go: `memory.max` and `cpu.max` as flags. Observe an OOM kill (`memory.events`, `dmesg`). |

**Acceptance:** a fork bomb inside the container is contained by `--pids-limit`; a
memory hog is killed at `--memory`; the cgroup directory is gone after exit.
**Podman tie-in:** `podman run --memory --cpus --pids-limit`, `podman stats`, exit code 137.
**Explain-back:** how does the kernel know which limits apply to a given process?

### Liz Rice checkpoint

At this point the program does what Liz Rice's "Containers From Scratch" does, with
`pivot_root` added.

1. Watch the talk. Note anything she does differently and why.
2. `strace -f` a real `podman run --rm alpine true` in the VM and find the calls you now
   recognise. List the ones you do not.
3. Journal: the first full end-to-end explanation.
4. **Decide the end scope** and update the milestones below: stay a learning tool with
   deep dives (M7-M9), or also aim for an OCI-compatible runtime podman can call (M10).

### M7 Rootless (user namespaces)

**Concept:** a user namespace maps UIDs inside to different UIDs outside, so a process can
be root inside the container and an ordinary user on the host. This is what makes rootless
podman possible, and what explains most of its odd permission behaviour.

Outline (lessons detailed when reached):
- `unshare --user --map-root-user`; `/proc/self/uid_map`, `gid_map`, `setgroups`.
- `/etc/subuid`, `/etc/subgid`, `newuidmap`/`newgidmap` and why they are setuid.
- Go: run the container without sudo; what stops working (cgroups, some mounts) and why.

**Acceptance:** `container-runtime run rootfs id` works without sudo and prints uid 0;
files created inside are owned by Bryan's user (or a subuid) on the VM.
**Podman tie-in:** "permission denied" on volumes, `--userns=keep-id`, `podman unshare`.

### M8 Images and overlayfs

**Concept:** an image is a stack of tar layers plus a JSON config. overlayfs presents the
read-only layers and one writable layer as a single directory.

Outline:
- `skopeo copy docker://alpine oci:alpine`; read `index.json`, the manifest, the config, the layer blobs.
- overlayfs by hand: `lowerdir`, `upperdir`, `workdir`; copy-on-write and whiteouts.
- Go: unpack layers, mount an overlay as the rootfs, apply `Cmd`/`Env` from the config.
- Go: bind-mount a host directory into the container (volumes).

**Acceptance:** `container-runtime run <oci-image-dir>` runs the image's default command;
changes inside do not alter the layers; two containers from one image do not see each
other's writes.
**Podman tie-in:** `podman image inspect`, `podman diff`, storage drivers, `-v` and `:Z`.

### M9 Networking

**Concept:** a network namespace starts with only a down loopback interface. Connectivity
is built from a veth pair, a bridge, routes and NAT.

Outline:
- `ip netns`, veth pairs, a bridge, addresses and routes by hand; ping between namespaces.
- NAT with nftables for outbound traffic; a DNAT rule to publish a port.
- `/etc/resolv.conf` and `/etc/hosts` in the container.
- Go: automate it for the container; clean up on exit.
- Reading: how rootless networking differs (pasta / slirp4netns), since there is no
  permission to create a veth on the host.

**Acceptance:** from inside the container, `wget` of an external site works; a server in
the container is reachable from the VM on a published port.
**Podman tie-in:** `podman network`, `-p`, netavark, why rootless ports below 1024 fail.

### M10 OCI runtime spec (tentative; decided at the checkpoint)

**Concept:** podman does not create containers itself; it writes a `config.json` bundle
and calls a runtime (crun or runc) with `create`, `start`, `state`, `kill`, `delete`.

Outline:
- Read the OCI runtime spec; inspect a bundle podman generated.
- Split `run` into `create` + `start`; keep state on disk; implement `state`, `kill`, `delete`.
- Read the namespaces, mounts, process and cgroup settings from `config.json`.

**Acceptance:** `podman --runtime /path/to/container-runtime run --rm alpine echo hi` works
in the VM.

---

## Reference material

- Liz Rice, "Containers From Scratch" (talk) and its repo `lizrice/containers-from-scratch`
- man pages: `namespaces(7)`, `clone(2)`, `unshare(1)`, `pid_namespaces(7)`,
  `mount_namespaces(7)`, `pivot_root(2)`, `cgroups(7)`, `user_namespaces(7)`, `veth(4)`
- Kernel docs: cgroup v2 (`Documentation/admin-guide/cgroup-v2.rst`), overlayfs
- OCI runtime-spec and image-spec
- Source to read once the basics are in: `crun`, `runc/libcontainer`
- Go: A Tour of Go, Effective Go, `os/exec` and `syscall` package docs
