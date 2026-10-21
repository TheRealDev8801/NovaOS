#!/usr/bin/env bash
# Emit the NovaOS MOTD for a given edition. Keeps the three profiles in step
# instead of three drifting copies of the same text.
#
# Usage: make-motd.sh <gaming|plasma|server> > airootfs/etc/motd
set -euo pipefail

case "${1:-}" in
  gaming) EDITION="Gaming" ;;
  plasma) EDITION="Plasma (Nova Desktop)" ;;
  server) EDITION="Server" ;;
  *) echo "usage: $0 <gaming|plasma|server>" >&2; exit 2 ;;
esac

cat <<EOF

  NovaOS ${EDITION}  —  https://novaos.aibotv2-hosting.biz

  This is a live session. Nothing has been written to your disks yet.
  Run  nova-setup  to install NovaOS, or just look around.

  Console logins use root with no password. Set one before installing:  passwd

EOF
