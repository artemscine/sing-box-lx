#!/usr/bin/env bash

set -e -o pipefail

prepare_apk_root() {
  APK_ROOT_DIR=$(mktemp -d)
  mkdir -p "$APK_ROOT_DIR/etc"
  cat > "$APK_ROOT_DIR/etc/passwd" <<EOF
root:x:$(id -u):$(id -g):root:/root:/sbin/nologin
EOF
  cat > "$APK_ROOT_DIR/etc/group" <<EOF
root:x:$(id -g):root
EOF
}

ARCHITECTURE="$1"
VERSION="$2"
BINARY_PATH="$3"
OUTPUT_PATH="$4"

if [ -z "$ARCHITECTURE" ] || [ -z "$VERSION" ] || [ -z "$BINARY_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
  echo "Usage: $0 <architecture> <version> <binary_path> <output_path>"
  exit 1
fi

PROJECT=$(cd "$(dirname "$0")/.."; pwd)

# Keep the fork release and router patch revision distinct in APK ordering.
if [[ "$VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-lx\.([0-9]+)-openwrt\.([0-9]+)$ ]]; then
  APK_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}-r${BASH_REMATCH[3]}"
elif [[ "$VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-lx\.([0-9]+)$ ]]; then
  APK_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}-r0"
else
  echo "Unsupported OpenWrt package version: $VERSION" >&2
  exit 1
fi

ROOT_DIR=$(mktemp -d)
prepare_apk_root
trap 'rm -rf "$ROOT_DIR" "$APK_ROOT_DIR"' EXIT

# Binary
install -Dm755 "$BINARY_PATH" "$ROOT_DIR/usr/bin/sing-box"

# Config files
install -Dm644 "$PROJECT/release/config/config.json" "$ROOT_DIR/etc/sing-box/config.json"
install -Dm644 "$PROJECT/release/config/openwrt.conf" "$ROOT_DIR/etc/config/sing-box"
install -Dm755 "$PROJECT/release/config/openwrt.init" "$ROOT_DIR/etc/init.d/sing-box"
install -Dm644 "$PROJECT/release/config/openwrt.keep" "$ROOT_DIR/lib/upgrade/keep.d/sing-box"

# Completions
install -Dm644 "$PROJECT/release/completions/sing-box.bash" "$ROOT_DIR/usr/share/bash-completion/completions/sing-box.bash"
install -Dm644 "$PROJECT/release/completions/sing-box.fish" "$ROOT_DIR/usr/share/fish/vendor_completions.d/sing-box.fish"
install -Dm644 "$PROJECT/release/completions/sing-box.zsh" "$ROOT_DIR/usr/share/zsh/site-functions/_sing-box"

# License
install -Dm644 "$PROJECT/LICENSE" "$ROOT_DIR/usr/share/licenses/sing-box/LICENSE"

# APK metadata
PACKAGES_DIR="$ROOT_DIR/lib/apk/packages"
mkdir -p "$PACKAGES_DIR"

cat > "$PACKAGES_DIR/.conffiles" <<'EOF'
/etc/config/sing-box
/etc/sing-box/config.json
EOF

while IFS= read -r conffile; do
  sha256=$(sha256sum "$ROOT_DIR$conffile" | cut -d' ' -f1)
  echo "$conffile $sha256"
done < "$PACKAGES_DIR/.conffiles" > "$PACKAGES_DIR/.conffiles_static"

(cd "$ROOT_DIR" && find . -type f -o -type l) \
  | sed 's|^\./|/|' \
  | grep -v '^/lib/apk/packages/' \
  | sort > "$PACKAGES_DIR/.list"

# Build APK (minimal dependencies: ca-bundle)
apk --root "$APK_ROOT_DIR" mkpkg \
  --info "name:sing-box" \
  --info "version:${APK_VERSION}" \
  --info "description:The universal proxy platform (slim build with xhttp for podkop)." \
  --info "arch:${ARCHITECTURE}" \
  --info "license:GPL-3.0-or-later" \
  --info "origin:sing-box" \
  --info "url:https://sing-box.sagernet.org/" \
  --info "maintainer:artemscine" \
  --info "depends:ca-bundle" \
  --info "provider-priority:100" \
  --script "pre-deinstall:${PROJECT}/release/config/openwrt.prerm" \
  --files "$ROOT_DIR" \
  --output "$OUTPUT_PATH"
