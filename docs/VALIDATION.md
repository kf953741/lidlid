# Validation status

This document separates the implemented workflow, software evidence, and physical evidence. Promotional illustrations describe the intended use case; they are not test results.

## Development configuration

| Configuration | Software checks | Physical lid-close/reopen |
| --- | --- | --- |
| Apple M5 Pro, macOS 27.0.1, Swift 6.4.2 | Build, UI, request lifecycle, and recovery checks passed | One local calculation close/reopen check completed |
| Other Apple Silicon MacBooks / macOS 14+ | Targeted by the build, not individually validated | Reports wanted |
| Intel Macs | Not supported by the session agent | Not supported |

## Completed software checks

- Four session tests, including 256 sequences of open/closed readings, one-shot consumption, cancellation reset, and deadline handling.
- Four localization tests: system-language fallback and explicit overrides, switching an existing result between languages, preservation of diagnostic codes, and English duration pluralization.
- Real IOKit activation and restoration requests accepted; two power assertions observed while active and absent after cancellation.
- Parent pipe EOF, heartbeat timeout, and agent SIGTERM cleanup paths.
- A real UI SIGKILL with agent cleanup; a real agent SIGKILL with surviving UI cleanup.
- Native UI on/off, duration selection, active deadline display, settings navigation, and return to the default off state.
- English and simplified Chinese native UI, immediate language changes during an active session, localized duration menus and deadline formatting, and a persisted language choice after relaunch. Each README uses captures of its matching interface.
- DMG checksum verification, a read-only mounted copy with the expected app version and matching app files, an Applications shortcut, and the actual Finder installation-window layout. The DMG and ZIP contain the same application build.

Historical local check summaries are in [software.json](validation/software.json) and [interface.json](validation/interface.json). They are snapshots, not a compatibility certification. Public CI tests the pure state machine and build only.

## Observed local-task close/reopen

On October 31, 2026, LidLid 1.2.0 was enabled on the development MacBook, on battery power with no external display. During a user-operated close/reopen cycle, an independent local calculation completed 44 work steps with the real lid sensor closed before and after each calculation. Consecutive closed-lid samples were at most 1.076 seconds apart. Reopening returned the UI to Off; the [Chinese capture](assets/zh-CN/demo-reopened.jpg) shows that result.

This was a small local calculation, not a recorded Codex or Claude Code session. It establishes one observed run on this configuration.

## Not yet established

- Closed-lid completion of actual Codex or Claude Code workflows, or long-duration workloads.
- Restoration of normal sleep on the following real lid close.
- Physical AC/battery transitions, external-display hot-plugging, login launch, low-battery stops, or thermal stops.
- Reliability across the targeted Mac models and macOS versions.

## First physical check

Use a ventilated desk, sufficient charge, no external display, and one lid controller. Start with a short test and an expendable local task.

1. Confirm that ordinary lid sleep behaves normally with LidLid off.
2. Enable LidLid and verify that it shows **已开启** (On).
3. Close the lid for about 30 seconds, then reopen it.
4. Check whether the task actually advanced while closed. Merely finding the process alive or seeing an accepted request is insufficient.
5. Confirm LidLid returns to off. Close the lid again and check that ordinary sleep is restored.
6. [Report the model, OS, power source, duration, and both results](https://github.com/kf953741/lidlid/issues/new?template=compatibility.yml).

Do not deliberately overheat the Mac, drain its battery to test the cutoff, or put it in a bag during this check. Keep the lid open and restart if restoration is uncertain.

## Optional real API check

With LidLid and Clamshell quit, lid open, and no external display:

```sh
python3 scripts/integration.py 'dist/LidLid.app/Contents/MacOS/LidLid'
```

This briefly activates and releases the actual interface. It does not close the lid or prove closed-lid operation.

Read-only diagnostic output:

```sh
'dist/LidLid.app/Contents/MacOS/LidLid' --check
```

The `phase` in this command's output is a default diagnostic snapshot, **not a query of an already running agent's session state**. Use the UI and event records to inspect the running session.
