#!/usr/bin/env python3
"""Archive a verified Store app with matching dSYMs and fresh metadata.

This does not upload, open Xcode, install services or access credentials.
"""
import argparse
import datetime
import plistlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
parser.add_argument('--app', type=Path, default=ROOT / 'dist/app-store/LidLid.app')
parser.add_argument('--output', type=Path)
parser.add_argument('--organizer', action='store_true', help='Copy the new archive into the local Xcode Organizer directory')
args = parser.parse_args()
app = args.app.resolve()
subprocess.run(['python3', str(ROOT / 'scripts/verify-app-store.py'), str(app)], check=True)
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
assert re.fullmatch(r'[0-9]+(?:\.[0-9]+)*', version) and build.isdigit(), 'Invalid archive version'
archive = (args.output or ROOT / f'.build/app-store-signing/LidLid-{version}-{build}.xcarchive').resolve()
if archive.exists():
    parser.error(f'Archive already exists; keep it intact and choose another output: {archive}')
signature = subprocess.run(['codesign', '-dv', '--verbose=2', str(app)], capture_output=True, text=True, check=True).stderr
identity = next(line.removeprefix('Authority=') for line in signature.splitlines() if line.startswith('Authority='))
team = next(line.removeprefix('TeamIdentifier=') for line in signature.splitlines() if line.startswith('TeamIdentifier='))
now = datetime.datetime.now(datetime.timezone.utc)
organizer = Path.home() / 'Library/Developer/Xcode/Archives' / now.astimezone().strftime('%Y-%m-%d') / archive.name
if args.organizer and organizer.exists():
    parser.error(f'Organizer archive already exists; it was not replaced: {organizer}')

(archive / 'Products/Applications').mkdir(parents=True)
subprocess.run(['ditto', str(app), str(archive / 'Products/Applications/LidLid.app')], check=True)
metadata = {
    'ApplicationProperties': {
        'ApplicationPath': 'Applications/LidLid.app',
        'Architectures': ['arm64'],
        'CFBundleIdentifier': info['CFBundleIdentifier'],
        'CFBundleShortVersionString': version,
        'CFBundleVersion': build,
        'SigningIdentity': identity,
        'Team': team,
    },
    'ArchiveVersion': 2,
    'CreationDate': now.replace(tzinfo=None),
    'Name': 'LidLid',
    'SchemeName': 'LidLid',
}
# Never inherit another archive's notarization/upload Distributions records.
(archive / 'Info.plist').write_bytes(plistlib.dumps(metadata))
for binary, name in [('MacOS/LidLid', 'LidLid.app.dSYM'), ('Helpers/LidLidAgent', 'LidLidAgent.dSYM')]:
    source, symbols = app / 'Contents' / binary, archive / 'dSYMs' / name
    symbols.parent.mkdir(exist_ok=True)
    subprocess.run(['dsymutil', str(source), '-o', str(symbols)], check=True)
    binary_uuid = subprocess.check_output(['dwarfdump', '--uuid', str(source)], text=True).split()[1]
    symbols_uuid = subprocess.check_output(['dwarfdump', '--uuid', str(symbols)], text=True).split()[1]
    assert binary_uuid == symbols_uuid, f'Symbol UUID mismatch: {name}'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(archive / 'Products/Applications/LidLid.app')], check=True)
if args.organizer:
    organizer.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['ditto', str(archive), str(organizer)], check=True)
    print(organizer)
else:
    print(archive)
