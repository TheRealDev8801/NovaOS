#!/usr/bin/env bash
# Reclaim disk after a NovaOS build.
#
# The recurring bloat is simple: every build writes ISOs to releng/../out, and
# those get copied to hosting/static/downloads for serving, so the same
# multi-GB files exist twice. This keeps the served copies (the download server
# reads only from there) and drops the build-output duplicates, after verifying
# they are byte-identical.
#
# Usage:
#   ./reclaim-disk.sh                 # verify + remove out/ ISOs, prune docker
#   ./reclaim-disk.sh --keep-out      # verify only, remove nothing
#   ./reclaim-disk.sh --drop-cache    # also drop the 2 GB pacman cache
set -euo pipefail

OUT_DIR="${NOVAOS_OUT:-/home/therealdev/novaos/out}"
SERVE_DIR="${NOVAOS_SERVE:-/home/therealdev/hosting/static/downloads}"
CACHE_DIR="${NOVAOS_CACHE:-$HOME/.cache/novaos-docker}"

KEEP_OUT=0
DROP_CACHE=0
for a in "$@"; do
  case "$a" in
    --keep-out) KEEP_OUT=1 ;;
    --drop-cache) DROP_CACHE=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

echo "=== before ==="
df -h / | tail -1

removed=0
shopt -s nullglob
for iso in "$OUT_DIR"/*.iso; do
  name="$(basename "$iso")"
  served="$SERVE_DIR/$name"
  if [[ ! -f "$served" ]]; then
    echo "KEEP    $name (not served yet — no copy in $SERVE_DIR)"
    continue
  fi
  if [[ "$(stat -c%s "$iso")" != "$(stat -c%s "$served")" ]]; then
    echo "KEEP    $name (size differs from served copy)"
    continue
  fi
  if [[ "$(md5sum <"$iso")" != "$(md5sum <"$served")" ]]; then
    echo "KEEP    $name (content differs from served copy)"
    continue
  fi
  if (( KEEP_OUT )); then
    echo "OK      $name (identical to served copy; --keep-out so not removed)"
  else
    rm -f "$iso"
    echo "REMOVED $name (identical duplicate; $(du -h "$served" | cut -f1) still served)"
    removed=$((removed + 1))
  fi
done

echo
echo "=== docker build cache ==="
docker builder prune -af 2>&1 | tail -1

if (( DROP_CACHE )); then
  echo
  echo "=== dropping pacman cache ($CACHE_DIR) ==="
  du -sh "$CACHE_DIR" 2>/dev/null || true
  rm -rf "$CACHE_DIR"
  echo "removed (next build re-downloads packages)"
fi

echo
echo "=== after ($removed duplicate ISO(s) removed) ==="
df -h / | tail -1
