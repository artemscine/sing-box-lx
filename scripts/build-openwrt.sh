#!/usr/bin/env bash
set -euo pipefail

project=$(cd "$(dirname "$0")/.." && pwd)
architecture=${1:?Usage: build-openwrt.sh x86_64|aarch64_cortex-a53 OUTPUT_DIRECTORY [slim: 0|1]}
output=${2:?Output directory required}
slim=${3:-1}
case "$architecture" in
  x86_64) goarch=amd64 ;;
  aarch64_cortex-a53) goarch=arm64 ;;
  *) echo "Unsupported architecture: $architecture" >&2; exit 1 ;;
esac
mkdir -p "$output"
output=$(cd "$output" && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
revision=$(bash "$project/scripts/prepare-openwrt.sh" "$scratch/source" "$slim")
version=${OPENWRT_BUILD_VERSION:-$(tr -d '[:space:]' < "$project/openwrt.version")}
toolchain=$(go version | awk '{print $3}')
expected_toolchain=$(tr -d '[:space:]' < "$project/go.version")
if [[ "$toolchain" != "$expected_toolchain" ]]; then
  echo "Expected $expected_toolchain, got $toolchain" >&2
  exit 1
fi
tags=with_quic,with_utls,with_clash_api,with_xhttp,badlinkname,tfogo_checklinkname0
[[ "$slim" == 1 ]] && tags="$tags,podkop_slim"
binary="$output/sing-box-$architecture"
(cd "$scratch/source" && CGO_ENABLED=0 GOOS=linux GOARCH="$goarch" go build \
  -trimpath -tags "$tags" \
  -ldflags "-s -w -buildid= -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=$version" \
  -o "$binary" ./cmd/sing-box)
bash "$project/.github/build_podkop_apk.sh" "$architecture" "$version" "$binary" \
  "$output/sing-box_${version}_openwrt_${architecture}.apk"
{
  printf 'version=%s\nsource_revision=%s\ntoolchain=%s\ntags=%s\n' "$version" "$revision" "$toolchain" "$tags"
  if [[ "$slim" == 1 ]]; then
    (cd "$project" && sha256sum patches/[0-9][0-9][0-9][0-9]-*.patch)
  fi
} > "$output/build-$architecture.txt"
(cd "$output" && sha256sum "$(basename "$binary")" "sing-box_${version}_openwrt_${architecture}.apk")
