#!/usr/bin/env bash
# NovaOS ISO build driver
# Requires archiso on an Arch Linux host:  pacman -S archiso
set -euo pipefail

cd "$(dirname "$0")"

# ── keep the shipped copies of the wizard in sync ─────────────────────────
# The scripts exist twice: once as the readable source under nova-setup/, and
# once inside each profile's airootfs, which is the copy archiso actually ships.
# Editing the source alone changes nothing in the ISO — that is exactly how a
# fixed nova-setup failed to reach a build, producing an ISO that still carried
# the broken archinstall config. Sync from the source on every build so the two
# can never drift apart again.
sync_wizard() {
  local src="$1" dst
  for dst in novaos-*/airootfs/usr/local/bin; do
    [[ -d "$dst" ]] || continue
    cp -f "${src}" "${dst}/"
    chmod 755 "${dst}/$(basename "$src")"
  done
}

sync_wizard "../nova-setup/nova-setup"
sync_wizard "../nova-setup/nova-first-login"

# Refuse to build if a shipped copy still differs from the source. Cheap, and it
# turns "silently shipped the wrong script" into a loud failure.
check_wizard_synced() {
  local src="$1" dst
  for dst in novaos-*/airootfs/usr/local/bin; do
    [[ -f "${dst}/$(basename "$src")" ]] || continue
    if ! cmp -s "$src" "${dst}/$(basename "$src")"; then
      echo "ERROR: ${dst}/$(basename "$src") differs from ${src}" >&2
      return 1
    fi
  done
}

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
  # Verify the initramfs actually contains the archiso hooks. Without
  # airootfs/etc/mkinitcpio.conf.d/archiso.conf the ISO builds fine but cannot
  # mount its own squashfs and dies at "Switch Root". Catch that here instead
  # of on a user's phone. See docs/archiso-profile-requirements.md
  if command -v lsinitcpio >/dev/null 2>&1 && command -v xorriso >/dev/null 2>&1; then
    local tmpd initrd
    tmpd="$(mktemp -d)"
    if xorriso -osirrox on -indev "$iso" \
         -extract "/novaos/boot/x86_64/initramfs-linux.img" "${tmpd}/initrd.img" \
         >/dev/null 2>&1; then
      initrd="${tmpd}/initrd.img"
      if ! lsinitcpio -a "$initrd" 2>/dev/null | grep -q 'archiso'; then
        rm -rf "$tmpd"
        echo "ERROR: ${profile}: initramfs has no archiso hooks — ISO would fail at Switch Root" >&2
        echo "       Missing airootfs/etc/mkinitcpio.conf.d/archiso.conf?" >&2
        return 1
      fi
      echo "==> ${profile}: initramfs archiso hooks present"
    fi
    rm -rf "$tmpd"
  fi
  # Verify files that must be executable actually are. archiso does not
  # preserve airootfs permissions: anything absent from the profile's
  # file_permissions array silently becomes 0644, so a script in the ISO can
  # fail with "Permission denied" even though it is 0755 in this repository.
  # See docs/desktop-splash-setup.md
  if command -v xorriso >/dev/null 2>&1 && command -v unsquashfs >/dev/null 2>&1; then
    local tmpd2
    tmpd2="$(mktemp -d)"
    if xorriso -osirrox on -indev "$iso" \
         -extract "/novaos/x86_64/airootfs.sfs" "${tmpd2}/root.sfs" \
         >/dev/null 2>&1; then
      local bad=0
      for f in usr/local/bin/nova-setup usr/local/bin/nova-first-login; do
        # Only check files this profile actually ships.
        if unsquashfs -l "${tmpd2}/root.sfs" "$f" >/dev/null 2>&1; then
          unsquashfs -d "${tmpd2}/x" "${tmpd2}/root.sfs" "$f" >/dev/null 2>&1
          if [[ ! -x "${tmpd2}/x/${f}" ]]; then
            echo "ERROR: ${profile}: ${f} is not executable inside the ISO" >&2
            echo "       Add it to file_permissions in profiledef.sh (0:0:755)" >&2
            bad=1
          fi
          # And that the ISO ships the CURRENT script, not a stale duplicate
          # left behind in the profile's airootfs. An ISO once shipped with a
          # fixed exec bit and an outdated script body, which is worse than
          # either failure alone because it looks like it worked.
          local want="../nova-setup/$(basename "$f")"
          if [[ -f "$want" ]] && ! cmp -s "$want" "${tmpd2}/x/${f}"; then
            echo "ERROR: ${profile}: ${f} inside the ISO differs from ${want}" >&2
            echo "       A stale copy in airootfs was built. Run the sync step." >&2
            bad=1
          fi
        fi
      done
      if (( bad )); then
        rm -rf "$tmpd2"
        return 1
      fi
      echo "==> ${profile}: required executables are executable"
    fi
    rm -rf "$tmpd2"
  fi
  echo "==> ${profile}: OK -> ${iso} ($(du -h "$iso" | cut -f1))"
  sha256sum "$iso"
}

# Fail before building anything if a profile copy drifted from the source.
check_wizard_synced "../nova-setup/nova-setup" || exit 1
check_wizard_synced "../nova-setup/nova-first-login" || exit 1

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
