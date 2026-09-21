#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/PokiSitelen.xcodeproj"
TARGET="PokiSitelen"
BUILD_ROOT="$ROOT/build/poki-sitelen-local-release"
DIST_ROOT="$ROOT/dist/poki-sitelen"
BUILT_APP="$BUILD_ROOT/Release/poki sitelen.app"
DIST_APP="$DIST_ROOT/poki sitelen.app"
DIST_ZIP="$DIST_ROOT/poki sitelen.zip"

rm -rf "$BUILD_ROOT" "$DIST_ROOT"
mkdir -p "$BUILD_ROOT" "$DIST_ROOT"

echo "Building poki sitelen Release configuration..."
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

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DIST_APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DIST_APP/Contents/Info.plist")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DIST_APP/Contents/Info.plist")
ARCHS=$(lipo -archs "$DIST_APP/Contents/MacOS/poki sitelen")

echo
echo "Release bundle checks:"
echo "  Version:       $VERSION ($BUILD)"
echo "  Bundle ID:     $BUNDLE_ID"
echo "  Architectures: $ARCHS"

if otool -L "$DIST_APP/Contents/MacOS/poki sitelen" | grep -q DFRFoundation; then
    echo "  DFRFoundation: linked"
else
    echo "  DFRFoundation: NOT FOUND"
    exit 1
fi

if codesign --verify --deep --strict "$DIST_APP" >/dev/null 2>&1; then
    echo "  Code signature: verified"
else
    echo "  Code signature: not verified"
fi

echo
echo "Standalone app:"
echo "  $DIST_APP"
echo "Zip archive:"
echo "  $DIST_ZIP"

if [[ "${1:-}" == "--install" ]]; then
    INSTALL_APP="/Applications/poki sitelen.app"

    if pgrep -x "poki sitelen" >/dev/null 2>&1; then
        echo "Stopping the currently running poki sitelen..."
        osascript -e 'tell application "poki sitelen" to quit' >/dev/null 2>&1 || true

        for _ in 1 2 3 4 5; do
            if ! pgrep -x "poki sitelen" >/dev/null 2>&1; then
                break
            fi
            sleep 0.2
        done

        if pgrep -x "poki sitelen" >/dev/null 2>&1; then
            echo "Old process is still running; stopping it forcefully..."
            pkill -x "poki sitelen" || true
            sleep 0.5
        fi
    fi

    echo "Installing to $INSTALL_APP..."
    rm -rf "$INSTALL_APP"
    ditto "$DIST_APP" "$INSTALL_APP"
    echo "Installed. Launching the standalone copy..."
    open "$INSTALL_APP"
fi
