#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
SCRATCH="${LIDLID_BUILD_DIR:-${LIDONCE_BUILD_DIR:-$ROOT/.build}}"
APP="${LIDLID_APP_PATH:-${LIDONCE_APP_PATH:-$ROOT/dist/LidLid.app}}"
ARCHS_RAW="${LIDLID_ARCHS:-arm64 x86_64}"
ARCH_FLAGS=()
for arch in ${=ARCHS_RAW}; do
    ARCH_FLAGS+=(--arch "$arch")
done
swift build --package-path "$ROOT" -c release "${ARCH_FLAGS[@]}" --scratch-path "$SCRATCH"
BIN_DIR="$(swift build --package-path "$ROOT" -c release "${ARCH_FLAGS[@]}" --scratch-path "$SCRATCH" --show-bin-path)"
SIGN_IDENTITY="${LIDLID_CODE_SIGN_IDENTITY:--}"
DISTRIBUTION="${LIDLID_DISTRIBUTION:-open-source}"
if [[ "${LIDLID_RELEASE:-0}" == "1" && "$SIGN_IDENTITY" == "-" ]]; then
    print -u2 'LIDLID_RELEASE=1 requires a non-ad-hoc LIDLID_CODE_SIGN_IDENTITY'
    exit 2
fi
case "$DISTRIBUTION" in
    open-source|app-store) ;;
    *) print -u2 'LIDLID_DISTRIBUTION must be open-source or app-store'; exit 2 ;;
esac
SIGN_FLAGS=(--force)
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN_FLAGS+=(--options runtime --timestamp)
fi
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SCRATCH/LidLid.iconset"
cp "$BIN_DIR/LidOnce" "$APP/Contents/MacOS/LidLid"
cp "$BIN_DIR/LidOnceAgent" "$APP/Contents/Helpers/LidLidAgent"
swift "$ROOT/scripts/export-brand-assets.swift" iconset "$ROOT/Resources/AppIcon.png" "$SCRATCH/LidLid.iconset"
iconutil -c icns "$SCRATCH/LidLid.iconset" -o "$APP/Contents/Resources/LidLid.icns"
for localization in en zh-Hans; do
    ditto "$ROOT/Resources/$localization.lproj" "$APP/Contents/Resources/$localization.lproj"
done
cp "$ROOT/Resources/PrivacyInfo.xcprivacy" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LidLidDistribution $DISTRIBUTION" "$APP/Contents/Info.plist"
codesign "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" --identifier dev.kf.lidonce.agent \
    --entitlements "$ROOT/Entitlements/LidLidAgent.entitlements" "$APP/Contents/Helpers/LidLidAgent"
codesign "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" --identifier dev.kf.lidonce \
    --entitlements "$ROOT/Entitlements/LidLid.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
print -r -- "$APP"
