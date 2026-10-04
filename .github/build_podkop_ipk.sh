#!/usr/bin/env bash
set -euo pipefail

architecture=${1:?Usage: build_podkop_ipk.sh ARCHITECTURE VERSION BINARY OUTPUT}
version=${2:?Version required}
binary=${3:?Binary required}
output=${4:?Output required}
project=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/data" "$work/control"
install -Dm755 "$binary" "$work/data/usr/bin/sing-box"
install -Dm644 "$project/release/config/config.json" "$work/data/etc/sing-box/config.json"
install -Dm644 "$project/release/config/openwrt.conf" "$work/data/etc/config/sing-box"
install -Dm755 "$project/release/config/openwrt.init" "$work/data/etc/init.d/sing-box"
install -Dm644 "$project/release/config/openwrt.keep" "$work/data/lib/upgrade/keep.d/sing-box"
install -Dm644 "$project/LICENSE" "$work/data/usr/share/licenses/sing-box/LICENSE"
size=$(du -sk "$work/data" | awk '{print $1}')
cat > "$work/control/control" <<EOF
Package: sing-box
Version: $version
Architecture: $architecture
Maintainer: artemscine
Section: net
Priority: optional
License: GPL-3.0-or-later
Depends: ca-bundle
Installed-Size: $((size * 1024))
Description: The universal proxy platform (router build with xhttp).
EOF
printf '/etc/config/sing-box\n/etc/sing-box/config.json\n' > "$work/control/conffiles"
install -m755 "$project/release/config/openwrt.prerm" "$work/control/prerm"
# OpenWrt opkg reads a tar container holding the control and data tarballs.
# Normalize archive metadata so packaging an existing release binary is reproducible.
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$work/data" . | gzip -n > "$work/data.tar.gz"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$work/control" . | gzip -n > "$work/control.tar.gz"
printf '2.0\n' > "$work/debian-binary"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$work" ./debian-binary ./control.tar.gz ./data.tar.gz | gzip -n > "$output"
