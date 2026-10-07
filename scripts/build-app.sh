#!/usr/bin/env bash
# Builds dist/AeroCheat.app (ad-hoc signed), dist/AeroCheat-<version>.dmg (drag to Applications) and
# dist/AeroCheat-<version>.zip from the sources.
# System tools only, no network, nothing installed; everything is written under the repository's dist/.
set -euo pipefail

fail() { echo "build-app.sh: error: $*" >&2; exit 1; }
trap 'echo "build-app.sh: failed at line $LINENO" >&2' ERR

[[ "$(uname -s)" == "Darwin" ]] || fail "this script only runs on macOS"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

[[ -f VERSION ]] || fail "VERSION file not found"
VERSION="$(tr -d '[:space:]' < VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] || fail "VERSION must look like 1.2.3, got '$VERSION'"
[[ -f Packaging/Info.plist ]] || fail "Packaging/Info.plist not found"
[[ -f Assets/AppIcon.icns ]] || fail "Assets/AppIcon.icns not found"

DIST="$ROOT/dist"
APP="$DIST/AeroCheat.app"
ZIP="$DIST/AeroCheat-$VERSION.zip"
DMG="$DIST/AeroCheat-$VERSION.dmg"
STAGING="$DIST/dmg-staging"
MOUNT="$DIST/dmg-mount"

echo "==> swift build -c release"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/AeroCheat"
[[ -x "$BIN" ]] || fail "release executable not found at $BIN"

echo "==> assembling $APP"
# Only ever delete the two outputs this script owns, inside dist/ under the repository.
rm -rf "$APP" "$ZIP" "$DMG" "$STAGING" "$MOUNT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AeroCheat"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed "s/@VERSION@/$VERSION/g" Packaging/Info.plist > "$APP/Contents/Info.plist"
grep -q '@VERSION@' "$APP/Contents/Info.plist" && fail "unfilled placeholder left in Info.plist"

echo "==> signing (ad hoc)"
codesign --force --deep --sign - "$APP"

echo "==> verifying"
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"
[[ -f "$APP/Contents/Resources/AppIcon.icns" ]] || fail "icon missing from the bundle"

echo "==> zipping"
# No extended attributes: they would ship as ._ files inside the archive.
ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP" "$ZIP"
[[ -s "$ZIP" ]] || fail "zip was not produced"

echo "==> disk image"
mkdir -p "$STAGING"
ditto --norsrc --noextattr --noqtn --noacl "$APP" "$STAGING/AeroCheat.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname AeroCheat -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
mkdir -p "$MOUNT"
hdiutil attach "$DMG" -readonly -nobrowse -noverify -mountpoint "$MOUNT" >/dev/null
trap 'hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true' EXIT
[[ -d "$MOUNT/AeroCheat.app" ]] || fail "AeroCheat.app missing from the disk image"
[[ -L "$MOUNT/Applications" && "$(readlink "$MOUNT/Applications")" == "/Applications" ]] || fail "Applications link missing from the disk image"
codesign --verify --deep --strict "$MOUNT/AeroCheat.app"
hdiutil detach "$MOUNT" -quiet
rm -rf "$STAGING" "$MOUNT"

echo "Built $APP"
echo "Built $DMG"
echo "Built $ZIP"
