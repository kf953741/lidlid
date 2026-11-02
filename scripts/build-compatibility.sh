#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
SCRATCH="${LIDLID_BUILD_DIR:-$ROOT/.build}"
APP="${LIDLID_COMPATIBILITY_APP_PATH:-$ROOT/dist/LidLid Compatibility.app}"
IDENTITY="${LIDLID_CODE_SIGN_IDENTITY:--}"
swift build --package-path "$ROOT" -c release --scratch-path "$SCRATCH"
BIN_DIR="$(swift build --package-path "$ROOT" -c release --scratch-path "$SCRATCH" --show-bin-path)"
python3 "$ROOT/scripts/configure-compatibility.py" "$APP" "$SCRATCH/compatibility-config" "$IDENTITY"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/HelperTools"
cp "$BIN_DIR/LidLidCompatibility" "$APP/Contents/MacOS/LidLidCompatibility"
cp "$BIN_DIR/LidLidSleepService" "$APP/Contents/Library/HelperTools/LidLidSleepService"
if [[ -f "$ROOT/dist/LidLid.app/Contents/Resources/LidLid.icns" ]]; then
    cp "$ROOT/dist/LidLid.app/Contents/Resources/LidLid.icns" "$APP/Contents/Resources/LidLid.icns"
fi
cp "$ROOT/Resources/PrivacyInfo.xcprivacy" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
codesign --force --options runtime --sign "$IDENTITY" --identifier dev.kf.lidonce.sleep-service \
    --entitlements "$SCRATCH/compatibility-config/service.entitlements" "$APP/Contents/Library/HelperTools/LidLidSleepService"
codesign --force --options runtime --sign "$IDENTITY" --identifier dev.kf.lidonce.compatibility \
    --entitlements "$SCRATCH/compatibility-config/service.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
print -r -- "$APP"
