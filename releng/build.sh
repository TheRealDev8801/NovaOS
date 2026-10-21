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
  local src="$1" dst file
  for dst in novaos-*/airootfs/usr/local/bin; do
    file="${dst}/$(basename "$src")"
    [[ -f "$file" ]] || continue
    # sha256sum, not cmp: cmp is not present in the archlinux:latest image the
    # Docker build uses. A missing command made `if ! cmp -s` succeed, so every
    # build failed claiming the files differed when they were identical.
    if [[ "$(sha256sum < "$src" | cut -d' ' -f1)" != "$(sha256sum < "$file" | cut -d' ' -f1)" ]]; then
      echo "ERROR: ${file} differs from ${src}" >&2
      return 1
    fi
  done
}

build() {
  local profile="$1" iso rc=0
  local outdir="$(cd "$(pwd)/../out" && pwd)"
  echo "==> Building NovaOS ISO: ${profile}"
  # Do NOT detect the fresh ISO with `find -newer <stamp>`. mkarchiso sets
  # SOURCE_DATE_EPOCH for reproducible builds, so the ISO's mtime can be OLDER
  # than a stamp taken at build start — the ordering is not guaranteed and the
  # check silently found nothing. Remove the expected output up front instead,
  # then its mere existence afterwards proves this build produced it.
  # Derive the ISO filename the way mkarchiso does: iso_name + iso_version.
  # iso_version is not a literal — it contains a command substitution, e.g.
  # "$(date +%Y.%m.%d)" — so it must be evaluated, not read verbatim, or the
  # filename will never match what mkarchiso writes.
  local name version
  name="$(sed -n 's/^iso_name="\(.*\)"/\1/p' "${profile}/profiledef.sh")"
  version="$(sed -n 's/^iso_version="\(.*\)"/\1/p' "${profile}/profiledef.sh")"
  version="$(eval printf '%s' "\"${version}\"")"
  iso="${outdir}/${name}-${version}-x86_64.iso"
  rm -f "$iso"
  # mkarchiso exits non-zero when a pacman hook fails inside the chroot, which
  # always happens: "Updating journal message catalog" and "Updating the
  # appstream cache" both call tools that need a running system. The ISO is
  # written BEFORE that point and is fine, so a non-zero exit here is not fatal.
  # Do not let it abort the script: the checks below are what decide whether the
  # build is good, and they must run even when mkarchiso complains.
  mkarchiso -v -w "/tmp/novaos-archiso-${profile}" -o "$outdir" "${profile}" || rc=$?
  if [[ ! -f "$iso" ]]; then
    echo "ERROR: ${profile}: mkarchiso exited ${rc} and produced no ISO" >&2
    echo "       expected: ${iso}" >&2
    return 1
  fi
  if (( rc != 0 )); then
    echo "==> ${profile}: mkarchiso exited ${rc} (chroot pacman hooks); ISO was written, continuing"
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
          # A fresh destination per file. Reusing one directory across loop
          # iterations makes unsquashfs refuse (the target already exists) and
          # return non-zero, which under `set -e` killed the whole build on the
          # second file — silently, before any of the checks reported.
          local ex="${tmpd2}/x-$(basename "$f")"
          rm -rf "$ex"
          unsquashfs -d "$ex" "${tmpd2}/root.sfs" "$f" >/dev/null 2>&1 || true
          if [[ ! -e "${ex}/${f}" ]]; then
            echo "ERROR: ${profile}: could not extract ${f} from the ISO to check it" >&2
            bad=1
            continue
          fi
          if [[ ! -x "${ex}/${f}" ]]; then
            echo "ERROR: ${profile}: ${f} is not executable inside the ISO" >&2
            echo "       Add it to file_permissions in profiledef.sh (0:0:755)" >&2
            bad=1
          fi
          # And that the ISO ships the CURRENT script, not a stale duplicate
          # left behind in the profile's airootfs. An ISO once shipped with a
          # fixed exec bit and an outdated script body, which is worse than
          # either failure alone because it looks like it worked.
          local want="../nova-setup/$(basename "$f")"
          if [[ -f "$want" ]] && \
             [[ "$(sha256sum < "$want" | cut -d' ' -f1)" != "$(sha256sum < "${ex}/${f}" | cut -d' ' -f1)" ]]; then
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
