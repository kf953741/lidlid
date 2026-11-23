# Security

LidLid separates the sandboxed Mac App Store main app from the privileged closed-lid compatibility helper:

- **Main app (`LidLid`):** App Sandboxed, zero network telemetry, never asks for your administrator password.
- **Compatibility helper (`LidLid Compatibility`):** Free, Developer ID signed, Apple notarized, and **100% open-source under MIT** for independent audit at [kf953741/lidlid-compatibility](https://github.com/kf953741/lidlid-compatibility).

Report security issues privately to **lidlid@bigsmart.cc**.
