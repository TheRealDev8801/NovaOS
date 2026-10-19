#!/usr/bin/env bash
# Boot a NovaOS ISO in QEMU for testing.
# Usage: ./run-vm.sh <path-to-novaos.iso> [extra qemu args...]
set -euo pipefail

iso="${1:-}"
if [[ -z "$iso" || ! -f "$iso" ]]; then
  echo "Usage: $0 <path-to-novaos.iso> [extra qemu args...]" >&2
  exit 1
fi
shift || true

kvm=()
if [[ -e /dev/kvm ]]; then
  kvm=(-enable-kvm -cpu host)
else
  echo "Note: /dev/kvm not available, using software emulation (slower)" >&2
fi

exec qemu-system-x86_64 \
  "${kvm[@]}" \
  -m 4096 \
  -smp 2 \
  -cdrom "$iso" \
  -boot d \
  -vga virtio \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  "$@"
