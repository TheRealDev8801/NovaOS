#!/usr/bin/env bash
# shellcheck disable=SC2034
# NovaOS Server profile definition

iso_name="novagos-server"
iso_label="NOVAOS_S_$(date +%Y%m%d)"
iso_publisher="NovaOS <https://novaos.aibotv2-hosting.biz>"
iso_application="NovaOS Server Live/Installation ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="novaos"
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
)
