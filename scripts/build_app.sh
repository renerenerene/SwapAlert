#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/dist/SwapAlert.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"

cd "$ROOT_DIR"
mkdir -p "$BUILD_DIR/module-cache" "$BUILD_DIR/swiftpm-cache" "$BUILD_DIR/swiftpm-config" "$BUILD_DIR/swiftpm-security"
swift build \
    -c release \
    --disable-sandbox \
    --scratch-path "$BUILD_DIR" \
    --cache-path "$BUILD_DIR/swiftpm-cache" \
    --config-path "$BUILD_DIR/swiftpm-config" \
    --security-path "$BUILD_DIR/swiftpm-security"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/release/SwapAlert" "$MACOS_DIR/SwapAlert"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

"$BUILD_DIR/release/IconGenerator" "$BUILD_DIR/AppIcon-1024.png"
cp "$BUILD_DIR/AppIcon-1024.png" "$RESOURCES_DIR/AppIcon.png"

xattr -cr "$APP_DIR"
xattr -c "$APP_DIR"
codesign --force --sign - --identifier local.swapalert.app "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "$APP_DIR"
