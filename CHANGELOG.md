# Changelog

## 1.6.1 (Upcoming Mac App Store Release)
- Redesigned native menu bar interface with Dark and Light appearances and live appearance switcher (`Auto / Light / Dark`).
- Added independent **Keep display awake** mode (`30 min`, `1 hour`, `Until off`, always free).
- Added Universal **Apple Silicon & Intel** support for MacBooks on macOS 14+, plus graceful desktop Mac mode for the two free open-lid switches.
- Hardened `LidLidSleepService` crash recovery, `pmset` fresh-Mac parsing, non-blocking XPC state mirroring, and pre-confirmation lifetime price disclosure on the 7-day trial sheet.
- Open-sourced the complete privileged compatibility helper under MIT at [kf953741/lidlid-compatibility](https://github.com/kf953741/lidlid-compatibility).

## 1.5.x
- Added free **Open-lid awake** mode (`PreventUserIdleSystemSleep` with bounded 30s timeout release).
- Introduced the separately installed, Developer ID signed & Apple notarized `LidLid Compatibility` component using `SMAppService.daemon` and mutual XPC CDHash pinning.

## 1.0 – 1.4
- Initial one-shot MacBook closed-lid keep-awake menu bar utility with bilingual Chinese/English UI, low-battery/thermal guards, and time limits.
