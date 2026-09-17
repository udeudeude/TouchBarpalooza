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
ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$DIST_ZIP"

echo
echo "Standalone app:"
echo "  $DIST_APP"
echo "Zip archive:"
echo "  $DIST_ZIP"

if codesign --verify --deep --strict "$DIST_APP" >/dev/null 2>&1; then
    echo "Code signature: verified"
else
    echo "Code signature: not verified"
    echo "The app can still be tested locally, but public distribution should use a stable signing identity."
fi

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
    echo "Installed."
    open "$INSTALL_APP"
fi
