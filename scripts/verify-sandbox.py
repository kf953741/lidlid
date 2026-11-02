#!/usr/bin/env python3
"""Verify the shipped signatures and inherited sandbox without changing power settings."""
import json
from pathlib import Path
import plistlib
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
binary = app / "Contents/MacOS/LidLid"
helper = app / "Contents/Helpers/LidLidAgent"

def entitlements(path):
    result = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", str(path)],
                            check=True, capture_output=True)
    return plistlib.loads(result.stdout)

subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
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
                  "rootDomainConnection": "passed", "version": info["CFBundleShortVersionString"],
                  "powerSettingsChanged": False}, indent=2))
