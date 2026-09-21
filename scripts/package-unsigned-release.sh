#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$ROOT/build/unsigned-release"
OUT_ROOT="$ROOT/dist/unsigned-release"
STAGE_ROOT="$BUILD_ROOT/staging"

rm -rf "$BUILD_ROOT" "$OUT_ROOT"
mkdir -p "$BUILD_ROOT" "$OUT_ROOT" "$STAGE_ROOT"

build_app() {
    local project="$1"
    local target="$2"
    local build_dir="$3"

    echo "Building $target without a Developer ID..."
    xcodebuild \
        -project "$ROOT/$project" \
        -target "$target" \
        -configuration Release \
        SYMROOT="$build_dir" \
        CODE_SIGNING_ALLOWED=NO \
        build
}

package_app() {
    local built_app="$1"
    local display_name="$2"
    local slug="$3"

    if [[ ! -d "$built_app" ]]; then
        echo "Expected app not found: $built_app"
        exit 1
    fi

    local version
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$built_app/Contents/Info.plist")

    local app_name
    app_name="$(basename "$built_app")"

    local staged="$STAGE_ROOT/$slug"
    local packaged_app="$staged/$app_name"
    local dmg="$OUT_ROOT/${slug}-${version}-unsigned.dmg"
    local zip="$OUT_ROOT/${slug}-${version}-unsigned.zip"

    rm -rf "$staged"
    mkdir -p "$staged"

    ditto "$built_app" "$packaged_app"

    # An ad-hoc signature does not identify the developer to Apple, but it gives
    # the bundle an internal code signature without requiring an Apple Developer
    # account. Gatekeeper will still require the user's explicit approval the
    # first time the downloaded app is opened.
    codesign --force --deep --sign - "$packaged_app"
    codesign --verify --deep --strict "$packaged_app"

    ln -s /Applications "$staged/Applications"
    cp "$ROOT/INSTALL_UNSIGNED.md" "$staged/READ ME FIRST.md"

    echo "Creating $display_name disk image..."
    hdiutil create \
        -volname "$display_name" \
        -srcfolder "$staged" \
        -ov \
        -format UDZO \
        "$dmg" >/dev/null

    ditto -c -k --sequesterRsrc --keepParent "$packaged_app" "$zip"

    echo "  $dmg"
    echo "  $zip"
}

build_app "TouchBarpalooza.xcodeproj" "TouchBarpalooza" "$BUILD_ROOT/touchbarpalooza"
build_app "PokiSitelen.xcodeproj" "PokiSitelen" "$BUILD_ROOT/poki-sitelen"

package_app \
    "$BUILD_ROOT/touchbarpalooza/Release/TouchBarpalooza.app" \
    "TouchBarpalooza" \
    "TouchBarpalooza"

package_app \
    "$BUILD_ROOT/poki-sitelen/Release/poki sitelen.app" \
    "poki sitelen" \
    "poki-sitelen"

echo
echo "Unsigned direct-download packages are in:"
echo "  $OUT_ROOT"
echo
echo "These builds are intentionally not Developer ID signed or notarized."
echo "See INSTALL_UNSIGNED.md for the first-open steps users will need."
