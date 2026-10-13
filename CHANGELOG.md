# Changelog

## 0.1.2

- `autoScanAndPickW628` now stops scanning as soon as a W628 advertisement is
  seen (early exit) instead of waiting for the full timeout.
- Scan logging includes `early_exit` and devices-seen metadata.

## 0.1.1

- Add pub.dev topics and richer description for discoverability
  (`health`, `fitness`, `sleep-tracking`, `spo2`, `flutterflow`).

## 0.1.0

- Initial release.
- `ApneicareSession` scan / connect / realtime CSV recording for W628.
- Protocol helpers: commands, checksum, realtime packet parser (3- and 4-byte SpO2 V1.2).
- MIT license; ready for pub.dev.
