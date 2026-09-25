# Installation & Setup Guide — apneicare_ble

## FlutterFlow Custom Package

1. Open FlutterFlow project → **Settings → Dependencies**.
2. Add custom package:

```yaml
apneicare_ble:
  git:
    url: https://github.com/VirtuousTechlogicMobile/apneicare_ble.git
```

3. Also ensure transitive deps are allowed: `flutter_blue_plus`, `permission_handler`, `path_provider`.
4. In **Custom Code**, import and use `ApneicareSession` (see README).
5. Upload CSV via your existing Resdent `UploadSleepTestFileSenseCall` custom action.

## Android (host app)

FlutterFlow → **Settings → Permissions** (or post-export Manifest). Needed:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

`minSdkVersion` ≥ 21 (prefer 23+). Target SDK 31+ requires runtime BLE permissions (handled via `permission_handler` in the package).

Overnight monitoring: configure foreground service types in the **host** app (same pattern as snore FGS custom code) — not inside this package.

## iOS (host app)

Info.plist / FlutterFlow permission strings:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is used to connect to your sleep sensor.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Bluetooth is used to connect to your sleep sensor.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required to scan for nearby Bluetooth sleep sensors.</string>
```

Background modes (if overnight reconnect needed):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-central</string>
</array>
```

## Verify

```bash
cd packages/apneicare_ble
flutter pub get
flutter test
```

Device smoke test: run `example/` against a powered W628.
