import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble/apneicare_ble_helper.dart';
import 'models/recording_result.dart';
import 'protocol/realtime_packet_parser.dart';
import 'recording/csv_writer.dart';

export 'ble/apneicare_ble_helper.dart';
export 'models/recording_result.dart';
export 'protocol/apneicare_commands.dart';
export 'protocol/checksum_calculator.dart';
export 'protocol/realtime_packet_parser.dart';
export 'recording/csv_writer.dart';

enum ApneicareSessionPhase {
  idle,
  scanning,
  connecting,
  connected,
  recording,
  stopping,
}

/// High-level W628 / Hushd Sense overnight session (scan → connect → CSV).
///
/// Upload, FlutterFlow UI, and foreground service stay in the host app.
class ApneicareSession {
  ApneicareSession({
    ApneicareBleHelper? ble,
    this.onLog,
  }) : _ble = ble ?? ApneicareBleHelper() {
    _ble.onLog = onLog;
  }

  final ApneicareBleHelper _ble;
  final void Function(
    String level,
    String code,
    String message, [
    Map<String, dynamic>? data,
  ])? onLog;

  final ApneicareCsvWriter _csv = ApneicareCsvWriter();
  StreamSubscription<List<int>>? _dataSub;
  ApneicareSessionPhase _phase = ApneicareSessionPhase.idle;
  DateTime? _recordingStart;
  bool _fingerOff = false;

  ApneicareSessionPhase get phase => _phase;
  bool get isConnected => _ble.isConnected;
  bool get isReadyForRealTime => _ble.isReadyForRealTime;
  bool get fingerOff => _fingerOff;
  String? get csvPath => _csv.path;
  int get rowCount => _csv.rowCount;
  BluetoothDevice? get connectedDevice => _ble.connectedDevice;
  Stream<List<int>>? get rawDataStream => _ble.dataStream;
  Stream<String>? get errorStream => _ble.errorStream;

  void Function(ApneicareSample sample)? onSample;
  void Function(bool fingerOff)? onProbeOff;

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final ok = statuses.values.every(
      (s) => s.isGranted || s.isLimited || s.isRestricted,
    );
    onLog?.call('event', 'permissions_result', 'Permission request finished', {
      'ok': ok,
      'statuses': statuses.map((k, v) => MapEntry(k.toString(), v.toString())),
    });
    return ok;
  }

  void initialize() {
    _ble.initialize();
    _phase = ApneicareSessionPhase.idle;
  }

  void prepareForReconnection() => _ble.prepareForReconnection();

  Future<List<BluetoothDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _phase = ApneicareSessionPhase.scanning;
    try {
      return await _ble.scanForDevices(timeout: timeout);
    } finally {
      if (_phase == ApneicareSessionPhase.scanning) {
        _phase = ApneicareSessionPhase.idle;
      }
    }
  }

  Future<BluetoothDevice?> autoScanAndPickW628({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _phase = ApneicareSessionPhase.scanning;
    try {
      return await _ble.autoScanAndPickW628(timeout: timeout);
    } finally {
      if (_phase == ApneicareSessionPhase.scanning) {
        _phase = ApneicareSessionPhase.idle;
      }
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    _phase = ApneicareSessionPhase.connecting;
    final ok = await _ble.connectToDevice(device);
    _phase =
        ok ? ApneicareSessionPhase.connected : ApneicareSessionPhase.idle;
    return ok;
  }

  Future<String> startRealtimeRecording({
    String? csvPath,
    String? fileName,
    void Function(ApneicareSample sample)? onSample,
    void Function(bool fingerOff)? onProbeOff,
  }) async {
    if (!_ble.isReadyForRealTime) {
      throw StateError('Device not ready for realtime (connect first)');
    }

    this.onSample = onSample ?? this.onSample;
    this.onProbeOff = onProbeOff ?? this.onProbeOff;

    resetRealtimePacketParser();
    if (csvPath != null) {
      await _csv.openExisting(csvPath);
    } else {
      await _csv.start(fileName: fileName);
    }

    await _dataSub?.cancel();
    _dataSub = _ble.dataStream?.listen(_onRawPacket);

    final started = await _ble.startRealTime();
    if (!started) {
      await _dataSub?.cancel();
      _dataSub = null;
      throw StateError('Failed to send realtime start command');
    }

    _recordingStart = DateTime.now();
    _phase = ApneicareSessionPhase.recording;
    return _csv.path!;
  }

  void _onRawPacket(List<int> data) {
    if (data.length >= 2 && data[0] == 0x55 && data[1] == 0xAA) return;
    if (data.length != 3 && data.length != 4) return;

    final rows = parseRealtimePacketToCsvRows(
      data,
      onFingerStatus: (off) {
        _fingerOff = off;
        this.onProbeOff?.call(off);
      },
    );
    for (final row in rows) {
      _csv.appendRow(row);
      final sample = ApneicareSample.fromCsvRow(row);
      onSample?.call(sample);
    }
  }

  Future<ApneicareRecordingResult> stopRecording() async {
    _phase = ApneicareSessionPhase.stopping;
    await _ble.stopRealTime();
    await _dataSub?.cancel();
    _dataSub = null;
    await _csv.close();
    final end = DateTime.now();
    final path = _csv.path;
    if (path == null || !File(path).existsSync()) {
      _phase = ApneicareSessionPhase.connected;
      throw StateError('No CSV file produced');
    }
    final result = ApneicareRecordingResult(
      csvPath: path,
      rowCount: _csv.rowCount,
      recordingStart: _recordingStart,
      recordingEnd: end,
    );
    _phase = ApneicareSessionPhase.connected;
    return result;
  }

  Future<int?> readBattery({
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _ble.readBattery(timeout: timeout);

  Future<void> disconnect() async {
    await _dataSub?.cancel();
    _dataSub = null;
    await _ble.disconnect();
    _phase = ApneicareSessionPhase.idle;
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
