#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/TouchBarpalooza.xcodeproj"
TARGET="TouchBarpalooza"
BUILD_ROOT="$ROOT/build/local-release"
DIST_ROOT="$ROOT/dist"
BUILT_APP="$BUILD_ROOT/Release/TouchBarpalooza.app"
DIST_APP="$DIST_ROOT/TouchBarpalooza.app"
DIST_ZIP="$DIST_ROOT/TouchBarpalooza.zip"
EXECUTABLE="$DIST_APP/Contents/MacOS/TouchBarpalooza"
INFO_PLIST="$DIST_APP/Contents/Info.plist"

rm -rf "$BUILD_ROOT" "$DIST_APP" "$DIST_ZIP"
mkdir -p "$BUILD_ROOT" "$DIST_ROOT"

echo "Building TouchBarpalooza Release configuration..."
xcodebuild \
    -project "$PROJECT" \
    -target "$TARGET" \
    -configuration Release \
    SYMROOT="$BUILD_ROOT" \
    build

if [[ ! -d "$BUILT_APP" ]]; then
    echo "Build completed, but the expected app bundle was not found:"
    echo "  $BUILT_APP"
    exit 1
fi

ditto "$BUILT_APP" "$DIST_APP"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "The app bundle does not contain the expected executable:"
    echo "  $EXECUTABLE"
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
ARCHITECTURES="$(lipo -archs "$EXECUTABLE" 2>/dev/null || true)"

echo
echo "Release bundle checks:"
echo "  Version:       $VERSION ($BUILD_NUMBER)"
echo "  Bundle ID:     $BUNDLE_ID"
echo "  Architectures: ${ARCHITECTURES:-unknown}"

if otool -L "$EXECUTABLE" | grep -q 'DFRFoundation'; then
    echo "  DFRFoundation: linked"
else
    echo "  DFRFoundation: NOT FOUND"
    exit 1
fi

if codesign --verify --deep --strict "$DIST_APP" >/dev/null 2>&1; then
    echo "  Code signature: verified"
else
    echo "  Code signature: not verified"
    echo "  The app can still be tested locally, but public distribution should use a stable signing identity."
fi

ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$DIST_ZIP"

echo
echo "Standalone app:"
echo "  $DIST_APP"
echo "Zip archive:"
echo "  $DIST_ZIP"

if [[ "${1:-}" == "--install" ]]; then
    INSTALL_APP="/Applications/TouchBarpalooza.app"

    if pgrep -x TouchBarpalooza >/dev/null 2>&1; then
        echo "Stopping the currently running TouchBarpalooza..."
        osascript -e 'tell application "TouchBarpalooza" to quit' >/dev/null 2>&1 || true
        sleep 1
    fi

    echo "Installing to $INSTALL_APP..."
    rm -rf "$INSTALL_APP"
    ditto "$DIST_APP" "$INSTALL_APP"
    echo "Installed. Launching the standalone copy..."
    open "$INSTALL_APP"
fi
