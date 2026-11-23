#!/bin/zsh
# Requires the owner's actual distribution identities and matching App Store
# profile. Never manufactures a submission package from a development signature.
set -euo pipefail
ROOT="${0:A:h:h}"
: "${LIDLID_STORE_APP_IDENTITY:?Set a Mac App Distribution or Apple Distribution signing identity}"
: "${LIDLID_STORE_INSTALLER_IDENTITY:?Set a Mac Installer Distribution signing identity}"
: "${LIDLID_STORE_PROFILE:?Set the downloaded Mac App Store provisioning profile path}"
STAGE="$ROOT/dist/app-store"
mkdir -p "$STAGE" "$ROOT/.build/app-store-signing"

python3 - "$ROOT" "$LIDLID_STORE_PROFILE" <<'PY'
from pathlib import Path
import datetime, plistlib, subprocess, sys
root, profile = Path(sys.argv[1]), Path(sys.argv[2])
p = plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(profile)], stderr=subprocess.DEVNULL))
assert p['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Profile expired'
assert not p.get('ProvisionsAllDevices') and not p.get('ProvisionedDevices'), 'An App Store distribution profile is required'
e = p['Entitlements']
assert not e.get('get-task-allow') and not e.get('com.apple.security.get-task-allow'), 'Development profiles cannot be submitted'
team = '63ALH54858'
assert team in p['TeamIdentifier'], 'Team differs from the authenticated compatibility service; migrate and retest before packaging'
app_key = next((k for k in ('com.apple.application-identifier','application-identifier') if k in e), None)
assert app_key and e[app_key] == team + '.dev.kf.lidonce', 'Bundle ID does not match this app'
desired = plistlib.loads((root/'Entitlements/LidLid.entitlements').read_bytes())
# macOS Team-ID-prefixed groups are authorized by the signing team, not by
# provisioning. Only the cross-platform group.* form needs profile approval.
assert all(g.startswith(team + '.') or g in e.get('com.apple.security.application-groups',[])
           for g in desired['com.apple.security.application-groups']), 'App group is not authorized for this team'
desired[app_key] = e[app_key]
desired['com.apple.developer.team-identifier'] = team
(root/'.build/app-store-signing/entitlements.plist').write_bytes(plistlib.dumps(desired))
PY

LIDLID_DISTRIBUTION=app-store LIDLID_APP_PATH="$STAGE/LidLid.app" LIDLID_CODE_SIGN_IDENTITY="$LIDLID_STORE_APP_IDENTITY" zsh "$ROOT/scripts/build.sh"
cp "$LIDLID_STORE_PROFILE" "$STAGE/LidLid.app/Contents/embedded.provisionprofile"
/usr/libexec/PlistBuddy -c 'Set :LidLidDistribution app-store' "$STAGE/LidLid.app/Contents/Info.plist"
codesign --force --options runtime --timestamp --sign "$LIDLID_STORE_APP_IDENTITY" \
  --identifier dev.kf.lidonce --entitlements "$ROOT/.build/app-store-signing/entitlements.plist" "$STAGE/LidLid.app"
python3 "$ROOT/scripts/verify-app-store.py" "$STAGE/LidLid.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGE/LidLid.app/Contents/Info.plist")
productbuild --component "$STAGE/LidLid.app" /Applications \
  --sign "$LIDLID_STORE_INSTALLER_IDENTITY" "$STAGE/LidLid-$VERSION-AppStore.pkg"
pkgutil --check-signature "$STAGE/LidLid-$VERSION-AppStore.pkg"
python3 - "$STAGE/LidLid-$VERSION-AppStore.pkg" <<'PY'
import re, subprocess, sys
signature = subprocess.check_output(['pkgutil','--check-signature',sys.argv[1]], text=True)
assert re.search(r'3rd Party Mac Developer Installer:.*\(63ALH54858\)', signature), 'A matching Mac Installer Distribution identity is required'
PY
print -r -- "$STAGE/LidLid-$VERSION-AppStore.pkg"
