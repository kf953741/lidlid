# LidLid Compatibility

The upcoming Mac App Store version remains a sandboxed Store app. Full closed-lid sessions on battery, without an external monitor, require a free component installed independently from the product website. The Store app never collects an administrator password or installs the component itself.

1. Download the Developer ID-signed and Apple-notarized component DMG from the website, then drag LidLid Compatibility to Applications. Development builds are not notarized production releases.
2. Open it and choose Install service. Follow macOS approval prompts, including System Settings → General → Login Items & Extensions if requested.
3. Return to LidLid, enable the session, and wait for On before closing the lid. Reopening ends it automatically.

Keep the component in Applications. Turn LidLid off before choosing manual Sleep. The active session temporarily prevents manual sleep as well. Online work still needs an internet connection.

To remove: switch LidLid off, open the component, choose Restore sleep & remove service, then delete the component only after successful restoration. Do not delete its recovery record first.

If the app exits, loses its connection or stops renewing its lease, the component restores the original global sleep setting. A stalled connection is bounded by a 30-second lease plus service processing time. Failed restoration retains a private recovery record for retries; service restart also recovers it before accepting another session.

Contact [kf953741@gmail.com](mailto:kf953741@gmail.com) if recovery fails. If the component has been damaged and the Mac refuses to sleep, an administrator can use `sudo pmset -a disablesleep 0` to restore the default. This sets a default; it cannot reconstruct a different original value stored in the component's journal.

Production signing, notarization, real closed-lid regression tests and Store submission validation remain required. Existing 1.3 screenshots need checking against the final 1.4 build. See the separate [engineering guide](COMPATIBILITY-ENGINEERING.md) for development checks.
