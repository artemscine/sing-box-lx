#!/usr/bin/env bash
set -euo pipefail

project=$(cd "$(dirname "$0")/.." && pwd)
destination=${1:?Usage: prepare-openwrt.sh NEW_DIRECTORY [slim: 0|1]}
slim=${2:-1}
case "$slim" in 0|1) ;; *) echo "slim must be 0 or 1" >&2; exit 1 ;; esac
if [[ -e "$destination" ]]; then
  echo "Destination must not exist: $destination" >&2
  exit 1
fi
revision=$(git -C "$project" rev-parse HEAD)
git clone --quiet --shared --no-checkout "$project" "$destination"
git -C "$destination" checkout --quiet --detach "$revision"
for module in gvisor sing-tun utls wireguard-go; do
  module_path="$project/submodules/$module"
  expected=$(git -C "$project" rev-parse "HEAD:submodules/$module")
  actual=$(git -C "$module_path" rev-parse HEAD)
  if [[ "$actual" != "$expected" ]]; then
    echo "Initialize pinned submodule submodules/$module before building" >&2
    exit 1
  fi
  rmdir "$destination/submodules/$module"
  git clone --quiet --shared --no-checkout "$module_path" "$destination/submodules/$module"
  git -C "$destination/submodules/$module" checkout --quiet --detach "$expected"
done
if [[ "$slim" == 1 ]]; then
  git -C "$destination" apply --check "$project/patches/0001-podkop-slim.patch"
  git -C "$destination" apply "$project/patches/0001-podkop-slim.patch"
  rm -f "$destination"/cmd/sing-box/cmd_api*.go
  for patch in "$project"/patches/[0-9][0-9][0-9][0-9]-*.patch; do
    [[ "$(basename "$patch")" == 0001-podkop-slim.patch ]] && continue
    git -C "$destination" apply --check "$patch"
    git -C "$destination" apply "$patch"
  done
fi
printf '%s\n' "$revision"
