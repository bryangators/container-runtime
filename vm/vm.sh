#!/usr/bin/env bash
# Disposable Fedora VM for running the container runtime safely.
# Plain QEMU/KVM as your own user: no sudo, no libvirt setup.
#
#   vm.sh up        download image (first time), create disk, boot, wait for provisioning
#   vm.sh down      shut the VM down
#   vm.sh status    running or stopped
#   vm.sh ssh [cmd] shell in the VM, or run one command
#   vm.sh sync      copy the repo into the VM (~/container-runtime)
#   vm.sh run ...   sync, build in the VM, run the binary as root with the given args
#   vm.sh run-user ...  same, without sudo (for the rootless milestone)
#   vm.sh test      sync, then `go test ./...` in the VM as root
#   vm.sh reset     throw the disk away and provision a fresh VM
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$REPO/vm/.state"

FEDORA_RELEASE="${FEDORA_RELEASE:-45}"
IMAGE_NAME="${IMAGE_NAME:-Fedora-Cloud-Base-Generic-45-1.4.x86_64.qcow2}"
CHECKSUM_NAME="${CHECKSUM_NAME:-Fedora-Cloud-45-1.4-x86_64-CHECKSUM}"
IMAGE_BASE_URL="https://dl.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Cloud/x86_64/images"

VM_CPUS="${VM_CPUS:-2}"
VM_MEM_MB="${VM_MEM_MB:-4096}"
VM_DISK="${VM_DISK:-20G}"
SSH_PORT="${SSH_PORT:-2222}"
VM_USER=fedora
REMOTE_DIR=container-runtime
BIN=bin/container-runtime

BASE="$STATE/$IMAGE_NAME"
DISK="$STATE/disk.qcow2"
SEED="$STATE/seed.iso"
KEY="$STATE/id_ed25519"
PIDFILE="$STATE/qemu.pid"
CONSOLE="$STATE/console.log"

SSH_OPTS=(-i "$KEY" -p "$SSH_PORT"
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR -o ConnectTimeout=5)

is_running() {
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

need_running() {
  is_running || { echo "VM is not running. Start it with: make vm-up" >&2; exit 1; }
}

vm_ssh() {
  ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "$@"
}

fetch_image() {
  [ -f "$BASE" ] && return
  echo "Downloading $IMAGE_NAME (about 500 MB, first time only)..."
  curl -fL --progress-bar -o "$BASE.part" "$IMAGE_BASE_URL/$IMAGE_NAME"
  curl -fsSL -o "$STATE/$CHECKSUM_NAME" "$IMAGE_BASE_URL/$CHECKSUM_NAME"
  local want got
  want=$(grep -E "^SHA256 \($IMAGE_NAME\)" "$STATE/$CHECKSUM_NAME" | awk '{print $NF}')
  got=$(sha256sum "$BASE.part" | awk '{print $1}')
  if [ -z "$want" ] || [ "$want" != "$got" ]; then
    echo "Checksum mismatch for $IMAGE_NAME (want '$want', got '$got')" >&2
    rm -f "$BASE.part"
    exit 1
  fi
  mv "$BASE.part" "$BASE"
  echo "Image verified (sha256)."
}

make_seed() {
  [ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N '' -C container-runtime-vm -f "$KEY"
  local dir="$STATE/seed"
  mkdir -p "$dir"
  sed "s|@SSH_PUBKEY@|$(cat "$KEY.pub")|" "$REPO/vm/user-data.tmpl" >"$dir/user-data"
  printf 'instance-id: crt-%s\nlocal-hostname: crt-vm\n' "$(date +%s)" >"$dir/meta-data"
  genisoimage -quiet -output "$SEED" -volid cidata -joliet -rock \
    "$dir/user-data" "$dir/meta-data"
}

cmd_up() {
  mkdir -p "$STATE"
  if is_running; then
    echo "VM already running."
    return
  fi
  fetch_image
  local fresh=0
  if [ ! -f "$DISK" ]; then
    fresh=1
    qemu-img create -q -f qcow2 -F qcow2 -b "$BASE" "$DISK" "$VM_DISK"
    make_seed
  fi
  : >"$CONSOLE"
  qemu-system-x86_64 \
    -name container-runtime-vm \
    -machine q35,accel=kvm -cpu host \
    -smp "$VM_CPUS" -m "$VM_MEM_MB" \
    -drive if=virtio,file="$DISK",format=qcow2 \
    -drive if=virtio,file="$SEED",format=raw,readonly=on \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"$SSH_PORT"-:22 \
    -display none -serial file:"$CONSOLE" \
    -daemonize -pidfile "$PIDFILE"

  echo -n "Waiting for SSH"
  local i
  for i in $(seq 1 90); do
    if vm_ssh true 2>/dev/null; then
      echo " ok"
      break
    fi
    echo -n .
    sleep 2
    if [ "$i" = 90 ]; then
      echo
      echo "VM did not come up. See $CONSOLE" >&2
      exit 1
    fi
  done

  if [ "$fresh" = 1 ]; then
    echo "First boot: installing packages in the VM (a few minutes)..."
  fi
  # Exit status 2 from cloud-init means "done, with recoverable warnings".
  vm_ssh 'cloud-init status --wait >/dev/null' || [ $? = 2 ]
  vm_ssh 'cloud-init status --long | sed -n 1,3p; go version; strace -V | head -1'
  echo "VM is up. Shell: make vm-ssh"
}

cmd_down() {
  if ! is_running; then
    echo "VM is not running."
    rm -f "$PIDFILE"
    return
  fi
  local pid
  pid=$(cat "$PIDFILE")
  vm_ssh 'sudo poweroff' 2>/dev/null || true
  local i
  for i in $(seq 1 30); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
  fi
  rm -f "$PIDFILE"
  echo "VM stopped."
}

cmd_status() {
  if is_running; then
    echo "running (pid $(cat "$PIDFILE"), ssh port $SSH_PORT)"
  else
    echo "stopped"
  fi
}

cmd_ssh() {
  need_running
  if [ $# -eq 0 ]; then
    ssh -t "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1"
  else
    vm_ssh "$@"
  fi
}

cmd_sync() {
  need_running
  rsync -az --delete \
    --exclude .git --exclude vm/.state --exclude bin --exclude rootfs \
    -e "ssh ${SSH_OPTS[*]}" \
    "$REPO/" "$VM_USER@127.0.0.1:$REMOTE_DIR/"
}

# Quote args so they survive the trip through ssh.
quote_args() {
  local out="" a
  for a in "$@"; do
    out+=" $(printf '%q' "$a")"
  done
  printf '%s' "$out"
}

run_in_vm() {
  local sudo_cmd="$1"
  shift
  cmd_sync
  local tty=()
  [ -t 0 ] && tty=(-t)
  ssh "${tty[@]}" "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" \
    "cd $REMOTE_DIR && go build -o $BIN . && $sudo_cmd ./$BIN$(quote_args "$@")"
}

cmd_test() {
  cmd_sync
  vm_ssh "cd $REMOTE_DIR && go vet ./... && sudo env PATH=\$PATH go test ./...$(quote_args "$@")"
}

cmd_reset() {
  cmd_down
  rm -rf "$DISK" "$SEED" "$STATE/seed"
  cmd_up
}

sub="${1:-}"
[ $# -gt 0 ] && shift
case "$sub" in
  up) cmd_up ;;
  down) cmd_down ;;
  status) cmd_status ;;
  ssh) cmd_ssh "$@" ;;
  sync) cmd_sync ;;
  run) run_in_vm sudo "$@" ;;
  run-user) run_in_vm "" "$@" ;;
  test) cmd_test "$@" ;;
  reset) cmd_reset ;;
  *)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
