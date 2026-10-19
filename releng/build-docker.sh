#!/usr/bin/env bash
# Build a NovaOS ISO using Docker — works with rootless Docker too.
#
# Rootless Docker runs containers inside a user namespace, where the kernel
# forbids mounting devtmpfs. pacstrap/arch-chroot use devtmpfs for the chroot
# /dev, so we patch them to rbind the container's /dev instead.
#
# Usage: ./build-docker.sh {gaming|server|all}
set -euo pipefail

cd "$(dirname "$0")"

build() {
  local target="$1"
  echo "==> Building NovaOS ISO via Docker: ${target}"
  docker run --rm --privileged \
    --cpus "${NOVAOS_BUILD_CPUS:-2}" \
    -v "$(pwd)/..:/novaos" \
    archlinux:latest \
    bash -c '
      set -e
      pacman -Syu --noconfirm archiso >/dev/null 2>&1
      sed -i "s|chroot_add_mount udev \"\$1/dev\" -t devtmpfs -o mode=0755,nosuid|chroot_add_mount /dev \"\$1/dev\" --rbind|" /usr/bin/pacstrap /usr/bin/arch-chroot
      cd /novaos/releng
      bash build.sh '"${target}"'
    '
}

case "${1:-}" in
  gaming|server|plasma|all) build "$1" ;;
  *)
    echo "Usage: $0 {gaming|server|all}" >&2
    exit 1
    ;;
esac

echo "==> Done. ISOs are in $(cd "$(pwd)/../out" 2>/dev/null && pwd || echo "$(pwd)/../out")"
