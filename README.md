# apneicare_ble

BLE session API for **Apneicare / Hushd Sense W628** overnight SpO₂ recording
(MD300W628 protocol). Pure Dart over [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus).

Host app (FlutterFlow) owns UI, Resdent upload, and foreground service.

## Install

### pub.dev

```yaml
dependencies:
  apneicare_ble: ^0.1.0
```

### GitHub (FlutterFlow Custom Package)

```yaml
dependencies:
  apneicare_ble:
    git:
      url: https://github.com/VirtuousTechlogicMobile/apneicare_ble.git
      ref: v0.1.0
```

### Local path (development)

```yaml
dependencies:
  apneicare_ble:
    path: ../apneicare_ble
```

## Quick start

```dart
import 'package:apneicare_ble/apneicare_ble.dart';

final session = ApneicareSession(
  onLog: (level, code, message, [data]) {
    print('[$level] $code: $message');
  },
);

session.initialize();
await session.requestPermissions();

final device = await session.autoScanAndPickW628();
if (device == null) return;

await session.connect(device);

final csvPath = await session.startRealtimeRecording(
  onSample: (s) => print('${s.dataType}=${s.value} probe=${s.probeStatus}'),
  onProbeOff: (off) => print('fingerOff=$off'),
);

// …overnight…

final result = await session.stopRecording();
await session.disconnect();

// Upload result.csvPath from FlutterFlow custom action
print('Saved ${result.rowCount} rows → ${result.csvPath}');
```

CSV row format: `value,data_type,probe_status` (e.g. `98,spo2,ON`).

## Platform setup

See [INSTALL_GUIDE.md](INSTALL_GUIDE.md) for Android / iOS permission strings
(host app / FlutterFlow Settings).

## License

MIT — see [LICENSE](LICENSE).
