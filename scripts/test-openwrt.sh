#!/usr/bin/env bash
set -euo pipefail

project=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
bash "$project/scripts/prepare-openwrt.sh" "$scratch/source" 1
cd "$scratch/source"
tags=with_quic,with_utls,with_clash_api,with_xhttp,badlinkname,tfogo_checklinkname0,podkop_slim
packages=(./route ./common/listener ./common/sniff ./common/tls ./dns/transport ./log ./protocol/group ./transport/v2rayxhttp ./protocol/vless/...)
go vet -tags "$tags" "${packages[@]}"
go test -ldflags=-checklinkname=0 -tags "$tags" "${packages[@]}"
if [[ ${OPENWRT_TEST_RACE:-0} == 1 ]]; then
  go test -race -ldflags=-checklinkname=0 -tags "$tags" ./route ./common/listener ./common/sniff ./common/tls ./dns/transport ./log
fi
