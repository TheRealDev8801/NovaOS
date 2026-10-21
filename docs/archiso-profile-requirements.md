# Boot-critical archiso profile files

Short version: **an archiso profile must ship
`airootfs/etc/mkinitcpio.conf.d/archiso.conf`.** Without it the initramfs is
built with plain Arch hooks, contains none of the `archiso` hooks, and the ISO
cannot mount its own squashfs — it dies at `Switch Root`.

## What went wrong (v0.1)

All three NovaOS profiles originally omitted that file. The resulting initramfs:

| | Broken | Fixed |
|---|---|---|
| Size | ~26 MB | ~215 MB |
| Compression | none (plain cpio) | xz |
| archiso hooks | **none** | `archiso archiso_loop_mnt archiso_pxe_*` |

Symptoms: `Failed to start Switch Root.` — identical on Gaming, Plasma and
Server, and impossible to fix from the QEMU command line, because the missing
logic lives inside the ISO's initramfs.

Stock Arch Linux booted fine in the same QEMU because stock *does* ship the file.

## The required file

`airootfs/etc/mkinitcpio.conf.d/archiso.conf`:

```
HOOKS=(base udev microcode modconf kms memdisk archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs block filesystems keyboard)
COMPRESSION="xz"
COMPRESSION_OPTIONS=(-9e)
```

## Verify a built ISO

```bash
xorriso -osirrox on -indev OUT.iso -extract /novaos/boot/x86_64/initramfs-linux.img /tmp/initrd.img
lsinitcpio -a /tmp/initrd.img | grep -A1 "Hook run order"
# expect: udev memdisk archiso archiso_loop_mnt archiso_pxe_common ...
lsinitcpio /tmp/initrd.img | grep hooks/archiso
```

If `Hook run order` has no `archiso`, the ISO will not boot.

## Confirmed in production

The fix is no longer only structurally verified. `novagos-gaming-2026.10.21-x86_64.iso`
(sha256 `9dde7aea…86cabd`) was booted on real hardware — Termux QEMU on an
Android phone — and **passed `Switch Root`**, reaching the live session. Every
earlier build, and every edition before this fix, failed at exactly that point.

That closes the original blocker. It is worth being explicit about what was
*not* the cause, because each was investigated at length:

| Suspect | Verdict |
|---|---|
| squashfs `-comp xz` / `-b 1M` | **Not the cause.** Stock Arch itself uses `-b 1M`. |
| QEMU `file.locking=off` | **Not the cause.** Keep it off — it avoids the Android lock error, but it never affected `Switch Root`. |
| `readonly=on` | **Not the cause.** Not a lock; harmless and kept. |
| Missing `archiso.conf` | **The actual root cause.** All three profiles omitted it. |

The guard added to `releng/build.sh` makes this class of regression impossible to
ship: it extracts the generated initramfs and fails the build if `lsinitcpio -a`
finds no `archiso` hooks.

## Other stock files we added

Also copied from `/usr/share/archiso/configs/releng/` so the live session is
actually usable:

- `etc/systemd/network/20-{ethernet,wlan,wwan}.network` — DHCP
- `etc/systemd/resolved.conf.d/archiso.conf` — mDNS/DNS
- `etc/locale.conf` — `LANG=C.UTF-8`
- `etc/systemd/system/etc-pacman.d-gnupg.mount` + `pacman-init.service` —
  pacman keyring
- `etc/systemd/system/multi-user.target.wants/` symlinks enabling
  `systemd-networkd`, `systemd-resolved`, `pacman-init`

Plus NovaOS-specific branding (`motd`, `hostname`, `shadow`, Plasma SDDM
autologin and guest agents).

## Not needed

`grub/`, `bootstrap_packages`, `choose-mirror`, `Installation_guide` — NovaOS
boots via syslinux + systemd-boot and has its own branding/install story.
