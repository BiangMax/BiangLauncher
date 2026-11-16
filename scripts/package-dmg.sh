#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP_DIR="$PROJECT_DIR/dist/BiangLauncher.app"
DMG_PATH="$PROJECT_DIR/dist/BiangLauncher-${APP_VERSION}-macOS-arm64.dmg"
DMG_PYTHON="$PROJECT_DIR/.build/dmg-tools/bin/python3"
if [[ ! -d "$APP_DIR" ]]; then
    echo "Run bash scripts/build.sh first." >&2
    exit 1
fi
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
[[ "$BUNDLE_VERSION" == "$APP_VERSION" ]] || { echo "App version differs from source. Rebuild first." >&2; exit 1; }
codesign --verify --deep --strict "$APP_DIR"
if [[ ! -x "$DMG_PYTHON" ]]; then
    python3 -m venv "$PROJECT_DIR/.build/dmg-tools"
fi
if ! "$DMG_PYTHON" -c 'import ds_store' >/dev/null 2>&1; then
    "$DMG_PYTHON" -m pip install 'ds-store==1.3.1' 'mac-alias==2.2.2'
fi
DMG_STAGE_DIR="$(mktemp -d "$PROJECT_DIR/.build/dmg-stage.XXXXXX")"
trap 'rm -rf "$DMG_STAGE_DIR"' EXIT
ditto --norsrc --noextattr --noacl "$APP_DIR" "$DMG_STAGE_DIR/BiangLauncher.app"
ln -s /Applications "$DMG_STAGE_DIR/Applications"
"$DMG_PYTHON" scripts/dmg-layout.py "$DMG_STAGE_DIR"
hdiutil create -volname "BiangLauncher $APP_VERSION" -srcfolder "$DMG_STAGE_DIR" -fs HFS+ -format UDZO -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH"
# Retain a local checksum for verification; the user-facing download is the DMG.
(cd "$PROJECT_DIR/dist" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256")
echo "Built: $DMG_PATH"
