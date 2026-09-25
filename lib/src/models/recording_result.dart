/// Result of an overnight Sense / Apneicare recording session.
class ApneicareRecordingResult {
  const ApneicareRecordingResult({
    required this.csvPath,
    required this.rowCount,
    this.recordingStart,
    this.recordingEnd,
  });

  final String csvPath;
  final int rowCount;
  final DateTime? recordingStart;
  final DateTime? recordingEnd;
}

/// A parsed realtime sample row (`value,data_type,probe_status`).
class ApneicareSample {
  const ApneicareSample({
    required this.value,
    required this.dataType,
    required this.probeStatus,
    required this.rawCsvRow,
  });

  final String value;
  final String dataType;
  final String probeStatus;
  final String rawCsvRow;

  factory ApneicareSample.fromCsvRow(String row) {
    final parts = row.split(',');
    return ApneicareSample(
      value: parts.isNotEmpty ? parts[0] : '',
      dataType: parts.length > 1 ? parts[1] : '',
      probeStatus: parts.length > 2 ? parts[2] : '',
      rawCsvRow: row,
    );
  }
}
