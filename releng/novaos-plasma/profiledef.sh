#!/usr/bin/env bash
# shellcheck disable=SC2034
# NovaOS Plasma profile definition (Plasma Nova desktop, QEMU-friendly)

iso_name="novagos-plasma"
iso_label="NOVAOS_PL$(date +%y%m%d)"
iso_publisher="NovaOS <https://novaos.aibotv2-hosting.biz>"
iso_application="NovaOS Plasma Live/Installation ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="novaos"
arch="x86_64"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# Match stock archiso: zstd with default 128K block size. NovaOS previously
# used '-b 1M' (and xz for Plasma), which produced images that failed to mount
# at switch-root under Android/QEMU while stock Arch booted fine.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
)
# NOTE: /home/nova is intentionally not listed here — it does not exist in the
# airootfs tree and archiso rejects permission entries for missing paths.
# The live user's home is created at boot by
# airootfs/usr/lib/tmpfiles.d/nova-home.conf (0700 nova:nova).

# Boot splash. splash = show plymouth; quiet = suppress kernel noise;
# vt.global_cursor_default=0 hides the blinking text cursor;
# loglevel=3 keeps the console calm. Applies to both syslinux and
# systemd-boot, which append %KERNEL_PARAMS%.
kernel_params="splash quiet loglevel=3 vt.global_cursor_default=0"
