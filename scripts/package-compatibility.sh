#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
APP="${1:-$ROOT/dist/LidLid Compatibility.app}"
python3 "$ROOT/scripts/verify-compatibility.py" "$APP"
STAGE="$(mktemp -d "$ROOT/.build/compatibility-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/LidLid Compatibility.app"
ln -s /Applications "$STAGE/Applications"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="${LIDLID_COMPATIBILITY_DMG_PATH:-$ROOT/dist/LidLid-Compatibility-$VERSION-macOS-arm64.dmg}"
hdiutil create -ov -format UDZO -srcfolder "$STAGE" -volname 'LidLid Compatibility' "$DMG"
hdiutil verify "$DMG"
print -r -- "$DMG"
