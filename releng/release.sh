#!/usr/bin/env bash
# NovaOS release driver — publishes built ISOs as GitHub Release assets.
#
# ISOs are NEVER committed to git: GitHub rejects files >100 MB and a multi-GB
# blob in history would bloat every clone. Release assets allow up to 2 GiB per
# file, so larger ISOs are split into parts automatically.
#
# Usage:
#   ./release.sh                 # publish every ISO found in ../out
#   ./release.sh v0.1.0          # publish under an explicit tag
#   ./release.sh v0.1.0 --draft  # create as a draft (not public yet)
set -euo pipefail

cd "$(dirname "$0")"
OUT="$(pwd)/../out"
TAG="${1:-v0.1.0}"
DRAFT=""
[[ "${2:-}" == "--draft" ]] && DRAFT="--draft"

# GitHub release assets are capped at 2 GiB; keep parts comfortably below.
MAX_ASSET=$((1900 * 1024 * 1024))

shopt -s nullglob
ISOS=("$OUT"/*.iso)
if ((${#ISOS[@]} == 0)); then
  echo "ERROR: no ISOs found in $OUT — build one first (./build-docker.sh plasma)" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

notes="$work/notes.md"
{
  echo "NovaOS **$TAG** — Arch-based GNU/Linux for gaming, servers and desktops."
  echo
  echo "| Image | Description |"
  echo "|---|---|"
  echo "| \`novagos-gaming\` | Gaming edition (optimized kernel, gaming toolchain) |"
  echo "| \`novagos-plasma\` | Plasma Nova desktop, QEMU/SPICE-friendly |"
  echo "| \`novagos-server\` | Minimal server edition |"
  echo
  echo "Verify your download with \`sha256sum -c SHA256SUMS\`."
} >"$notes"

assets=()
for iso in "${ISOS[@]}"; do
  name="$(basename "$iso")"
  size="$(stat -c%s "$iso")"
  printf '==> %s (%s)\n' "$name" "$(awk "BEGIN{printf \"%.2f GiB\", $size/1073741824}")"
  sha256sum "$iso" | sed "s|$OUT/||" >>"$work/SHA256SUMS"

  if ((size <= MAX_ASSET)); then
    assets+=("$iso")
    continue
  fi

  echo "    over the 2 GiB asset limit -> splitting into 1900 MiB parts"
  mkdir -p "$work/parts"
  split -b 1900M -d -a 2 "$iso" "$work/parts/$name.part"
  for part in "$work"/parts/*; do
    assets+=("$part")
  done
  {
    echo
    echo "### Reassembling \`$name\`"
    echo
    echo '```bash'
    echo "cat $name.part* > $name"
    echo "sha256sum -c SHA256SUMS --ignore-missing"
    echo '```'
  } >>"$notes"
done

assets+=("$work/SHA256SUMS")

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Release $TAG already exists; uploading assets"
else
  echo "==> Creating GitHub release $TAG"
  gh release create "$TAG" ${DRAFT:+$DRAFT} --title "NovaOS $TAG" --notes-file "$notes"
fi

echo "==> Uploading ${#assets[@]} asset(s)"
gh release upload "$TAG" "${assets[@]}" --clobber

echo "==> Done: $(gh release view "$TAG" --json url -q .url)"
