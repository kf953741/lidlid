#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
APP="${1:-$ROOT/dist/Lidune.app}"
SCRATCH="${LIDUNE_DMG_WORK_DIR:-$ROOT/.build/dmg}"
[[ -d "$APP" ]] || { print -u2 -- "Build the app first: zsh scripts/build.sh"; exit 1; }
APP="${APP:A}"
codesign --verify --strict "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/LidOnce")"
[[ "$ARCH" == arm64 ]] || { print -u2 -- "This preview packages Apple Silicon only; found: $ARCH"; exit 1; }
DMG="${LIDUNE_DMG_PATH:-$ROOT/dist/Lidune-${VERSION}-macOS-arm64.dmg}"
mkdir -p "$SCRATCH" "${DMG:h}"
python3 -m venv "$SCRATCH/venv"
"$SCRATCH/venv/bin/python" -m pip install --quiet --disable-pip-version-check -r "$ROOT/scripts/requirements-dmg.txt"
swift "$ROOT/scripts/dmg-background.swift" "$SCRATCH/background.tiff" "$VERSION"
"$SCRATCH/venv/bin/dmgbuild" -s "$ROOT/scripts/dmg-settings.py" \
    -D app="$APP" -D background="$SCRATCH/background.tiff" "Lidune" "$DMG"
hdiutil verify "$DMG"
print -r -- "$DMG"
