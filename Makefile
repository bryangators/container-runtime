# container-runtime
#
# Edit on the host. Run anything that touches namespaces, mounts or cgroups in the VM.
#
#   make build                 compile on the host (compile check only; do not run it here)
#   make vm-up                 boot the VM (first run downloads and provisions it)
#   make vm-ssh                shell in the VM
#   make vm-run ARGS="run ls"  sync, build in the VM, run the binary as root
#   make vm-run-user ARGS=...  same without sudo (rootless milestone)
#   make vm-test               go vet + go test in the VM as root
#   make vm-sync               copy the repo into the VM
#   make vm-status             running or stopped
#   make vm-reset              throw the VM disk away and start clean
#   make vm-down               shut the VM down

BIN  := bin/container-runtime
VM   := ./vm/vm.sh
ARGS ?=

.PHONY: build fmt vet vm-up vm-down vm-status vm-ssh vm-sync vm-run vm-run-user vm-test vm-reset

build:
	CGO_ENABLED=0 go build -o $(BIN) .

fmt:
	gofmt -l -w .

vet:
	go vet ./...

vm-up:
	$(VM) up

vm-down:
	$(VM) down

vm-status:
	@$(VM) status

vm-ssh:
	$(VM) ssh

vm-sync:
	$(VM) sync

vm-run:
	$(VM) run $(ARGS)

vm-run-user:
	$(VM) run-user $(ARGS)

vm-test:
	$(VM) test

vm-reset:
	$(VM) reset
