#!/usr/bin/env python3
"""Inspect packaging and signatures only. Does NOT register or run a root service."""
from pathlib import Path
import plistlib
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
service = app / 'Contents/Library/HelperTools/LidLidSleepService'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
expected_group = '63ALH54858.dev.kf.lidonce'
for path in [app, service]:
    entitlements = plistlib.loads(subprocess.check_output(
        ['codesign', '-d', '--entitlements', '-', '--xml', str(path)], stderr=subprocess.DEVNULL))
    assert entitlements == {'com.apple.security.application-groups': [expected_group]}, entitlements
    assert not entitlements.get('com.apple.security.app-sandbox')
plist = plistlib.loads((app / ('Contents/Library/LaunchDaemons/' + expected_group + '.sleep-service.plist')).read_bytes())
assert plist['MachServices'] == {expected_group + '.sleep-service': True}
assert plist['BundleProgram'] == 'Contents/Library/HelperTools/LidLidSleepService'
assert plist['KeepAlive'] and plist['RunAtLoad']
subprocess.run([str(service), '--self-test'], check=True)
print('Compatibility packaging passed; no daemon registration or power setting changes')
