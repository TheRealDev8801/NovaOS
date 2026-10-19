#!/usr/bin/env bash
# NovaOS ISO build driver
# Requires archiso on an Arch Linux host:  pacman -S archiso
set -euo pipefail

cd "$(dirname "$0")"

build() {
  local profile="$1"
  echo "==> Building NovaOS ISO: ${profile}"
  mkarchiso -v -w "/tmp/novaos-archiso-${profile}" -o "$(pwd)/../out" "${profile}"
}

case "${1:-}" in
  gaming) build "novaos-gaming" ;;
  plasma) build "novaos-plasma" ;;
  server) build "novaos-server" ;;
  all)
    build "novaos-gaming"
    build "novaos-plasma"
    build "novaos-server"
    ;;
  *)
    echo "Usage: $0 {gaming|plasma|server|all}" >&2
    exit 1
    ;;
esac

echo "==> Done. ISOs are in $(pwd)/../out"
