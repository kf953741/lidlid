#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
APP="${1:-$ROOT/dist/LidLid.app}"
SCRATCH="${LIDLID_DMG_WORK_DIR:-${LIDUNE_DMG_WORK_DIR:-$ROOT/.build/dmg}}"
[[ -d "$APP" ]] || { print -u2 -- "Build the app first: zsh scripts/build.sh"; exit 1; }
APP="${APP:A}"
VERIFY_ARGS=()
[[ "${LIDLID_RELEASE:-0}" == "1" ]] && VERIFY_ARGS+=(--release)
[[ "${LIDLID_REQUIRE_NOTARIZATION:-0}" == "1" ]] && VERIFY_ARGS+=(--notarized)
python3 "$ROOT/scripts/verify-sandbox.py" "${VERIFY_ARGS[@]}" "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
MAIN_ARCH="$(lipo -archs "$APP/Contents/MacOS/LidLid" | tr ' ' '\n' | sort | xargs)"
AGENT_ARCH="$(lipo -archs "$APP/Contents/Helpers/LidLidAgent" | tr ' ' '\n' | sort | xargs)"
[[ "$MAIN_ARCH" == "$AGENT_ARCH" ]] || { print -u2 -- "Architecture mismatch: app=$MAIN_ARCH helper=$AGENT_ARCH"; exit 1; }
case "$MAIN_ARCH" in
    "arm64 x86_64") ARCH_LABEL="universal" ;;
    "arm64"|"x86_64") ARCH_LABEL="$MAIN_ARCH" ;;
    *) print -u2 -- "Unsupported architecture set: $MAIN_ARCH"; exit 1 ;;
esac
DMG="${LIDLID_DMG_PATH:-${LIDUNE_DMG_PATH:-$ROOT/dist/LidLid-${VERSION}-macOS-${ARCH_LABEL}.dmg}}"
mkdir -p "$SCRATCH" "${DMG:h}"
python3 -m venv "$SCRATCH/venv"
"$SCRATCH/venv/bin/python" -m pip install --quiet --disable-pip-version-check -r "$ROOT/scripts/requirements-dmg.txt"
swift "$ROOT/scripts/dmg-background.swift" "$SCRATCH/background.tiff" "$VERSION"
"$SCRATCH/venv/bin/dmgbuild" -s "$ROOT/scripts/dmg-settings.py" \
    -D app="$APP" -D background="$SCRATCH/background.tiff" "LidLid" "$DMG"
if [[ -n "${LIDLID_CODE_SIGN_IDENTITY:-}" && "$LIDLID_CODE_SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$LIDLID_CODE_SIGN_IDENTITY" "$DMG"
fi
hdiutil verify "$DMG"
print -r -- "$DMG"
