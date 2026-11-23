#!/usr/bin/env python3
"""Verify the shipped signatures and inherited sandbox without changing power settings."""
import argparse
import json
from pathlib import Path
import plistlib
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--release", action="store_true", help="Require production team, hardened runtime and timestamp")
parser.add_argument("--notarized", action="store_true", help="Require stapled notarization ticket and Gatekeeper acceptance")
parser.add_argument("app", type=Path)
args = parser.parse_args()

app = args.app.resolve()
binary = app / "Contents/MacOS/LidLid"
helper = app / "Contents/Helpers/LidLidAgent"

def entitlements(path):
    result = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", str(path)],
                            check=True, capture_output=True)
    return plistlib.loads(result.stdout)

def archs(path):
    return sorted(subprocess.check_output(["lipo", "-archs", str(path)], text=True).split())

subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
app_archs = archs(binary)
helper_archs = archs(helper)
assert app_archs == helper_archs, f"Architecture mismatch: app={app_archs} helper={helper_archs}"
if args.release or args.notarized:
    for target in (app, helper):
        info_txt = subprocess.check_output(["codesign", "-dvv", str(target)], stderr=subprocess.STDOUT, text=True)
        assert "TeamIdentifier=63ALH54858" in info_txt, f"Missing production team on {target}:\n{info_txt}"
        assert "(runtime)" in info_txt, f"Hardened runtime missing on {target}:\n{info_txt}"
        assert "Timestamp=" in info_txt, f"Secure timestamp missing on {target}:\n{info_txt}"
if args.notarized:
    subprocess.run(["xcrun", "stapler", "validate", str(app)], check=True)
    subprocess.run(["spctl", "-a", "-vv", str(app)], check=True)
assert entitlements(app) == {"com.apple.security.app-sandbox": True,
                             "com.apple.security.application-groups": ["63ALH54858.dev.kf.lidonce"]}
assert entitlements(helper) == {"com.apple.security.app-sandbox": True,
                                "com.apple.security.inherit": True}
with (app / "Contents/Info.plist").open("rb") as file:
    info = plistlib.load(file)
with (app / "Contents/Resources/PrivacyInfo.xcprivacy").open("rb") as file:
    privacy = plistlib.load(file)
assert privacy["NSPrivacyTracking"] is False
assert privacy["NSPrivacyCollectedDataTypes"] == []
child = subprocess.Popen([str(binary), "--sandbox-check"], stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True)
try:
    output, errors = child.communicate(timeout=10)
except BaseException:
    child.kill()
    child.wait()
    raise
assert child.returncode == 0, (output, errors)
runtime = json.loads(output)
container_suffix = f"/Library/Containers/{info['CFBundleIdentifier']}/Data"
assert runtime["sandboxContainer"].endswith(container_suffix), runtime
assert runtime["agentPID"] != child.pid, runtime
assert runtime["rootDomainOpened"] is True, runtime
print(json.dumps({"sandboxSignatures": "passed", "inheritedContainer": "passed",
                  "rootDomainConnection": "passed", "architectures": app_archs,
                  "version": info["CFBundleShortVersionString"],
                  "powerSettingsChanged": False}, indent=2))
