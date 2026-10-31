#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
SCRATCH="${LIDLID_BUILD_DIR:-${LIDONCE_BUILD_DIR:-$ROOT/.build}}"
APP="${LIDLID_APP_PATH:-${LIDONCE_APP_PATH:-$ROOT/dist/LidLid.app}}"
swift build --package-path "$ROOT" -c release --scratch-path "$SCRATCH"
BIN_DIR="$(swift build --package-path "$ROOT" -c release --scratch-path "$SCRATCH" --show-bin-path)"
SIGN_IDENTITY="${LIDLID_CODE_SIGN_IDENTITY:--}"
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SCRATCH/LidLid.iconset"
cp "$BIN_DIR/LidOnce" "$APP/Contents/MacOS/LidLid"
cp "$BIN_DIR/LidOnceAgent" "$APP/Contents/Helpers/LidLidAgent"
if [[ -f "$ROOT/Resources/AppIcon.png" ]]; then
    cp "$ROOT/Resources/AppIcon.png" "$SCRATCH/icon.png"
else
    swift "$ROOT/scripts/icon.swift" "$SCRATCH/icon.png"
fi
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$SCRATCH/icon.png" --out "$SCRATCH/LidLid.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$SCRATCH/icon.png" --out "$SCRATCH/LidLid.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SCRATCH/LidLid.iconset" -o "$APP/Contents/Resources/LidLid.icns"
for localization in en zh-Hans; do
    ditto "$ROOT/Resources/$localization.lproj" "$APP/Contents/Resources/$localization.lproj"
done
cp "$ROOT/Resources/PrivacyInfo.xcprivacy" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign "$SIGN_IDENTITY" --identifier dev.kf.lidonce.agent \
    --entitlements "$ROOT/Entitlements/LidLidAgent.entitlements" "$APP/Contents/Helpers/LidLidAgent"
codesign --force --sign "$SIGN_IDENTITY" --identifier dev.kf.lidonce \
    --entitlements "$ROOT/Entitlements/LidLid.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
print -r -- "$APP"
