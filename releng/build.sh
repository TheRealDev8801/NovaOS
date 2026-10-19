#!/usr/bin/env bash
# NovaOS ISO build driver
# Requires archiso on an Arch Linux host:  pacman -S archiso
set -euo pipefail

cd "$(dirname "$0")"

build() {
  local profile="$1" stamp iso
  echo "==> Building NovaOS ISO: ${profile}"
  stamp="$(mktemp)"
  mkarchiso -v -w "/tmp/novaos-archiso-${profile}" -o "$(pwd)/../out" "${profile}"
  # Verify a fresh ISO was actually produced. Guards against a build that
  # "succeeds" but emits nothing (e.g. archiso aborting mid-way).
  iso="$(find "$(pwd)/../out" -maxdepth 1 -name '*.iso' -newer "$stamp" -print -quit)"
  rm -f "$stamp"
  if [[ -z "$iso" ]]; then
    echo "ERROR: ${profile}: build finished but produced no ISO" >&2
    return 1
  fi
  echo "==> ${profile}: OK -> ${iso} ($(du -h "$iso" | cut -f1))"
  sha256sum "$iso"
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
