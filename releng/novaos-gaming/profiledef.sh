#!/usr/bin/env bash
# shellcheck disable=SC2034
# NovaOS Gaming profile definition

iso_name="novagos-gaming"
iso_label="NOVAOS_G_$(date +%Y%m%d)"
iso_publisher="NovaOS <https://novaos.aibotv2-hosting.biz>"
iso_application="NovaOS Gaming Live/Installation ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="novaos"
arch="x86_64"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
)

# Boot splash. splash = show plymouth; quiet = suppress kernel noise;
# vt.global_cursor_default=0 hides the blinking text cursor;
# loglevel=3 keeps the console calm. Applies to both syslinux and
# systemd-boot, which append %KERNEL_PARAMS%.
kernel_params="splash quiet loglevel=3 vt.global_cursor_default=0"
