#!/usr/bin/env python3
"""Verify a real distribution bundle; does not upload, run UI or change power."""
from pathlib import Path
import datetime
import hashlib
import plistlib
import subprocess
import sys
import tempfile

app = Path(sys.argv[1]).resolve()
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['LidLidDistribution'] == 'app-store', 'Purchase gating is not enabled'
assert info['CFBundleIdentifier'] == 'dev.kf.lidonce'
subprocess.run(['codesign','--verify','--deep','--strict',str(app)], check=True)
profile = plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(app/'Contents/embedded.provisionprofile')], stderr=subprocess.DEVNULL))
assert profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
assert not profile.get('ProvisionsAllDevices') and not profile.get('ProvisionedDevices')
allowed = profile['Entitlements']
assert not allowed.get('get-task-allow') and not allowed.get('com.apple.security.get-task-allow')
entitlements = plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements','-','--xml',str(app)], stderr=subprocess.DEVNULL))
assert entitlements['com.apple.security.app-sandbox'] is True
assert entitlements['com.apple.security.application-groups'] == ['63ALH54858.dev.kf.lidonce']
assert entitlements['com.apple.developer.team-identifier'] == '63ALH54858'
assert set(entitlements) <= {'com.apple.security.app-sandbox','com.apple.security.application-groups',
    'com.apple.application-identifier','application-identifier','com.apple.developer.team-identifier'}
app_keys = [key for key in ('com.apple.application-identifier','application-identifier') if key in entitlements]
assert len(app_keys) == 1, 'A profile-authorized application identifier is required'
assert entitlements[app_keys[0]] == allowed[app_keys[0]] == '63ALH54858.dev.kf.lidonce'
helper = app/'Contents/Helpers/LidLidAgent'
main_archs = sorted(subprocess.check_output(['lipo','-archs',str(app/'Contents/MacOS/LidLid')], text=True).split())
helper_archs = sorted(subprocess.check_output(['lipo','-archs',str(helper)], text=True).split())
assert main_archs == ['arm64', 'x86_64'] and helper_archs == ['arm64', 'x86_64'], (
    f'App Store package must be Universal (arm64 + x86_64); found app={main_archs} helper={helper_archs}'
)
child = plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements','-','--xml',str(helper)], stderr=subprocess.DEVNULL))
assert child == {'com.apple.security.app-sandbox': True,'com.apple.security.inherit': True}
with tempfile.TemporaryDirectory() as tmp:
    # Match the actual leaf certificate to one authorized by the profile.
    prefix = str(Path(tmp)/'cert')
    subprocess.run(['codesign','-d','--extract-certificates='+prefix,str(app)], check=True, capture_output=True)
    leaf = Path(prefix+'0').read_bytes()
    assert any(hashlib.sha256(leaf).digest() == hashlib.sha256(c).digest() for c in profile['DeveloperCertificates'])
    description = subprocess.check_output(['codesign','-dvv',str(app)], stderr=subprocess.STDOUT, text=True)
    assert 'Authority=Apple Distribution:' in description or 'Authority=3rd Party Mac Developer Application:' in description, 'Development signing is not App Store distribution signing'
privacy = plistlib.loads((app/'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False and privacy['NSPrivacyCollectedDataTypes'] == []
print('App Store distribution signature, profile, sandbox, purchase mode and privacy manifest passed; not uploaded')
