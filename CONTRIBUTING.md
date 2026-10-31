# Contributing

The most useful contribution right now is a specific workflow or a compatibility report.

- [Report a physical close/open result](https://github.com/kf953741/lidune/issues/new?template=compatibility.yml).
- [Describe a feature need](https://github.com/kf953741/lidune/issues/new?template=feature_request.yml).
- [Report a bug](https://github.com/kf953741/lidune/issues/new?template=bug_report.yml).

Please distinguish an accepted power request, a process remaining alive, and actual task progress during a physical lid close. Also report whether the following lid close restores ordinary sleep.

## Development

```sh
swift test
zsh scripts/build.sh
```

The UI is in `PanelView.swift` and `App.swift`; the one-shot logic is in `LidOnceCore`; the session process and power interface are in `Agent.swift` and `Power.swift`.

Keep normal presentation to two states: off and on. The internal armed/closed distinction is still needed to consume one complete close/open cycle correctly. Preserve explicit failure messages and cleanup behavior when changing power handling.

Use pure state-machine tests for automation. Real API checks require a suitable local Mac and change its power state temporarily; do not run them on hosted CI. Follow [Validation](docs/VALIDATION.md) for the current evidence and manual procedure.

Do not include credentials, access-bearing URLs, personal project contents, or unrelated logs in reports. A short, redacted Lidune event excerpt is usually enough.
