#!/usr/bin/env bash
# Builds server/vm/output/TheEmptySchoolServer.ova. Needs Packer and VirtualBox on the build machine.
# Usage: server/vm/build-ova.sh [memory in MB]
set -euo pipefail

# Add common installation paths if running on Windows / Git Bash
if ! command -v VBoxManage >/dev/null 2>&1; then
	if [ -d "/c/Program Files/Oracle/VirtualBox" ]; then
		export PATH="/c/Program Files/Oracle/VirtualBox:$PATH"
	elif [ -n "${VBOX_MSI_INSTALL_PATH:-}" ] && [ -d "$VBOX_MSI_INSTALL_PATH" ]; then
		export PATH="$VBOX_MSI_INSTALL_PATH:$PATH"
	fi
fi

if ! command -v packer >/dev/null 2>&1; then
	if [ -n "${LOCALAPPDATA:-}" ] && [ -d "$LOCALAPPDATA/Microsoft/WinGet/Links" ]; then
		export PATH="$LOCALAPPDATA/Microsoft/WinGet/Links:$PATH"
	fi
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	echo "Usage: $0 [memory in MB]"
	exit 0
fi

vm_dir="$(cd "$(dirname "$0")" && pwd)"
game_dir="$(cd "$vm_dir/../.." && pwd)"
memory="${1:-1024}"
context="$(mktemp -d)/game-context.tar"

for tool in packer VBoxManage tar; do
	command -v "$tool" >/dev/null 2>&1 || { echo "$tool was not found." >&2; exit 1; }
done

# Same files the Docker build copies. The .dockerignore entries stay out of the archive.
tar -C "$game_dir" --exclude=./.godot --exclude=./build --exclude=./docs --exclude=./server/vm/output \
	--exclude=./scripts/staff.gd -cf "$context" .

rm -rf "$vm_dir/output"
cd "$vm_dir"
packer init neumann-vm.pkr.hcl
packer build -var "game_context=$context" -var "memory_mb=$memory" neumann-vm.pkr.hcl
rm -f "$context"
mv output/*.ova output/TheEmptySchoolServer.ova 2>/dev/null || true
echo "Done: $vm_dir/output/TheEmptySchoolServer.ova"
