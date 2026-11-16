#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"
swift build --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" -c release --arch arm64
BIN_DIR="$(swift build --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" -c release --arch arm64 --show-bin-path)"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP_DIR="$PROJECT_DIR/dist/BiangLauncher.app"
ARCHIVE_NAME="BiangLauncher-${APP_VERSION}-macOS-arm64.zip"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/BiangLauncher" "$APP_DIR/Contents/MacOS/BiangLauncher"
# Remove debug symbol paths before signing a publicly distributed executable.
xcrun strip -S -x "$APP_DIR/Contents/MacOS/BiangLauncher"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
swift scripts/make-icon.swift "$PROJECT_DIR/.build/AppIcon.iconset"
iconutil -c icns "$PROJECT_DIR/.build/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$APP_DIR" "$PROJECT_DIR/dist/$ARCHIVE_NAME"
(cd "$PROJECT_DIR/dist" && shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256")
echo "Built: $APP_DIR"
