import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Appends Sense CSV rows (`value,data_type,probe_status`) to a file.
class ApneicareCsvWriter {
  File? _file;
  int _rowCount = 0;

  File? get file => _file;
  String? get path => _file?.path;
  int get rowCount => _rowCount;

  static const String headerLine = 'value,data_type,probe_status';

  Future<String> start({String? fileName}) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = fileName ??
        'sense_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
    _file = File('${dir.path}/$name');
    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
    }
    // Header on first chunk only — write once when the file is empty.
    if (await _file!.length() == 0) {
      await _file!.writeAsString('$headerLine\n');
    }
    _rowCount = 0;
    return _file!.path;
  }

  Future<void> openExisting(String absolutePath) async {
    _file = File(absolutePath);
    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
    }
    if (await _file!.length() == 0) {
      await _file!.writeAsString('$headerLine\n');
    }
    _rowCount = 0;
  }

  void appendRow(String csvRow) {
    final f = _file;
    if (f == null) return;
    f.writeAsStringSync('$csvRow\n', mode: FileMode.append);
    _rowCount++;
  }

  Future<void> close() async {
    // File handle is OS-managed; nothing to close for sync appends.
  }
}
