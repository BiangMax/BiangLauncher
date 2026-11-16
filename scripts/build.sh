#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"
swift build --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" -c release --arch arm64
BIN_DIR="$(swift build --disable-sandbox --cache-path "$PROJECT_DIR/.build/cache" -c release --arch arm64 --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/BiangLauncher.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/BiangLauncher" "$APP_DIR/Contents/MacOS/BiangLauncher"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
swift scripts/make-icon.swift "$PROJECT_DIR/.build/AppIcon.iconset"
iconutil -c icns "$PROJECT_DIR/.build/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
ditto -c -k --keepParent "$APP_DIR" "$PROJECT_DIR/dist/BiangLauncher-0.1.0-macOS-arm64.zip"
echo "Built: $APP_DIR"
