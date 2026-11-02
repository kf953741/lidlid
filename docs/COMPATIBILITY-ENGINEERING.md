# Closed-lid compatibility architecture

The commercial distribution target remains the Mac App Store. The Store app remains sandboxed. The user independently installs a free, Developer ID signed and notarized compatibility app from the product website. Approval is requested by macOS Service Management, never by collecting a password in LidLid. App Review approval is not implied by this architecture.

## Cause and change

The November 1 failure happened before the November 2 macOS update. A display wake followed by WindowServer DMGrace expiry caused powerd to clear the shared selector-12 clamshell bit and immediately initiate Clamshell Sleep. Polling that bit faster cannot make ownership reliable. New sessions do not call selector 12.

The independently installed component registers a root LaunchDaemon through `SMAppService.daemon`. Its only operations are status, begin, renew, end, and prepare-for-removal. It runs `/usr/bin/pmset` with fixed arguments to read and temporarily set **system-wide** `SleepDisabled`. This is not a per-power-source setting; `pmset -g custom` is not an authoritative snapshot. See [Apple pmset source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m).

## Boundaries and recovery

- The App Group-prefixed Mach service allows sandbox lookup without a temporary sandbox exception. The inherited worker shares the main sandbox. Client and service pin each other's Apple-anchored Team ID and bundle identifiers. Only the current console user's approved clients are accepted.
- There is one session owner per XPC connection; another connection cannot renew or cancel it. Removal explicitly pauses all new sessions before restoring. No generic shell, caller-supplied file path, sudoers rule, password storage, private power entitlement or remote service is exposed.
- A 30-second continuous-clock lease is renewed every 5 seconds. The worker's UI heartbeat timeout remains 12 seconds. The daemon independently observes lid reopening, battery <=10% on battery, thermal pressure, sensor loss and optional duration. The worker additionally checks displays and the competing app. Clock adjustments do not extend daemon leases.
- Before mutation, the root daemon writes a root-owned 0600 recovery journal in a fixed 0700 directory using no-follow directory-relative operations, full file sync and rename. The journal contains only schema and the original boolean. Startup, termination, disconnect, expiry, removal and safety stops restore and read back the original setting before clearing the journal. Failed restoration retains the journal and retries.
- Existing `SleepDisabled=1` is refused; LidLid does not claim ownership of another utility's override. A different application's later change causes the session to stop rather than fight over settings. Concurrent external sleep controllers remain unsupported.
- This global setting temporarily prevents manual sleep as well. Users must turn LidLid off before choosing Sleep or putting the Mac in a bag. Shutdown/forced power-off is not intercepted.

## Build and verify

`zsh scripts/build.sh` and `zsh scripts/build-compatibility.sh` create separate bundles. By default they use ad-hoc signatures: XPC deliberately rejects these signatures. Never distribute them as a working production component.

For local development, set `LIDLID_CODE_SIGN_IDENTITY` to an Apple Development identity for team `63ALH54858`. Use a matching Developer ID Application identity for external production distribution, enable hardened runtime, notarize and staple the component DMG. Configure Store provisioning and App Group under the same team, sign the main app for App Store distribution, then validate through App Store Connect. Credentials/profiles must remain outside Git.

The compatibility app must be in `/Applications` before registering its bundled LaunchDaemon. Building and CI never register it or change power settings.

Checks:

```sh
swift test
python3 scripts/verify-sandbox.py dist/LidLid.app
python3 scripts/verify-compatibility.py 'dist/LidLid Compatibility.app'
dist/LidLid.app/Contents/MacOS/LidLid --compatibility-status
# After explicit macOS service approval, UI quit, lid open and no external display:
python3 scripts/integration.py dist/LidLid.app/Contents/MacOS/LidLid
```

Unit tests use injected power/journal objects. They cover restoration failure, crash recovery, partial mutation, expiry, ownership, safety, deadlines and signature syntax. They do not establish root permissions, sandbox XPC reachability, physical lid behavior or App Review acceptance. Open-lid integration checks actual persistent state and restoration, including worker SIGKILL. Physical validation must additionally cover battery/no monitor, >10-second closed-lid display-wake regression, AC/battery transitions, normal subsequent lid sleep, and reboot/daemon restart recovery.

## Primary references

- [Apple App Review Guidelines, 2.4.5 and 2.5.1](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Service Management](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Apple powerd assertion policy](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmconfigd/PMAssertions.c)
- [Apple root-domain user client](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/Kernel/RootDomainUserClient.cpp)
- [Rouse Store listing](https://apps.apple.com/us/app/rouse-stay-awake/id6760773101?mt=12) and [public companion architecture](https://github.com/JaminZhou/Rouse-Closed-Lid-Helper), consulted as implementation references; no third-party helper code is bundled.
