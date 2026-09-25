import 'package:apneicare_ble/apneicare_ble.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ApneicareBleExampleApp());
}

class ApneicareBleExampleApp extends StatelessWidget {
  const ApneicareBleExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'apneicare_ble example',
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late final ApneicareSession _session;
  String _status = 'idle';
  String? _csvPath;
  int _rows = 0;

  @override
  void initState() {
    super.initState();
    _session = ApneicareSession(
      onLog: (level, code, message, [data]) {
        debugPrint('[$level] $code: $message $data');
      },
    );
    _session.initialize();
  }

  Future<void> _run() async {
    setState(() => _status = 'permissions…');
    final ok = await _session.requestPermissions();
    if (!ok) {
      setState(() => _status = 'permissions denied');
      return;
    }

    setState(() => _status = 'scanning W628…');
    final device = await _session.autoScanAndPickW628();
    if (device == null) {
      setState(() => _status = 'no W628 found');
      return;
    }

    setState(() => _status = 'connecting ${device.platformName}…');
    final connected = await _session.connect(device);
    if (!connected) {
      setState(() => _status = 'connect failed');
      return;
    }

    setState(() => _status = 'recording…');
    final path = await _session.startRealtimeRecording(
      onSample: (_) => setState(() => _rows = _session.rowCount),
    );
    setState(() {
      _csvPath = path;
      _status = 'recording to $path (tap Stop)';
    });
  }

  Future<void> _stop() async {
    setState(() => _status = 'stopping…');
    final result = await _session.stopRecording();
    await _session.disconnect();
    setState(() {
      _csvPath = result.csvPath;
      _rows = result.rowCount;
      _status = 'done: ${result.rowCount} rows';
    });
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('apneicare_ble')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status),
            if (_csvPath != null) Text('CSV: $_csvPath'),
            Text('Rows: $_rows'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _run, child: const Text('Scan & Record')),
            ElevatedButton(onPressed: _stop, child: const Text('Stop')),
          ],
        ),
      ),
    );
  }
}
