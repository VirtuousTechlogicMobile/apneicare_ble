int _low7(int b) => b & 0x7F;
bool _isStatusByte(int b0) => (b0 & 0x80) != 0;
bool _fingerOffFromB0(int b0) => (b0 & 0x40) != 0;

int _prFrom(int b1, int b2) {
  final msb = (b1 >> 6) & 0x01;
  return (msb << 7) | (b2 & 0x7F);
}

double _spo2CombineToPercent(int low7v, int high7v) {
  final raw14 = (high7v << 7) | low7v;
  double v = raw14 / 10.0;
  if (v > 100.0) v = raw14 / 100.0;
  if (v < 0) v = 0;
  if (v > 100) v = 100;
  return v;
}

int? _spo2LowPending;
bool? _lastFingerOff;

/// Reset sticky parser state (call when starting a new recording session).
void resetRealtimePacketParser() {
  _spo2LowPending = null;
  _lastFingerOff = null;
}

/// Parse ONE realtime packet (3 or 4 bytes) -> 0 or 1 CSV rows:
/// `value,data_type,probe_status`
///
/// Protocol V1.2: SpO2 packets may be 4 bytes
/// (Byte0=Status, Byte1=DataStatus, Byte2=low7, Byte3=high7).
List<String> parseRealtimePacketToCsvRows(
  List<int> frame, {
  void Function(bool fingerOff)? onFingerStatus,
}) {
  final out = <String>[];

  if (frame.length < 3 || frame.length > 4) return out;

  final b0 = frame[0], b1 = frame[1], b2 = frame[2];
  final b3 = frame.length == 4 ? frame[3] : null;

  if (!_isStatusByte(b0)) return out;
  if ((b1 & 0x80) != 0 || (b2 & 0x80) != 0) return out;

  final fingerOff = _fingerOffFromB0(b0);
  if (onFingerStatus != null && _lastFingerOff != fingerOff) {
    _lastFingerOff = fingerOff;
    onFingerStatus(fingerOff);
  }
  final probe = fingerOff ? 'OFF' : 'ON';

  String row(dynamic value, String dataType) => '$value,$dataType,$probe';

  final ds = b1 & 0x3F;

  const DS_WAVEFORM = 0;
  const DS_SPO2 = 1;
  const DS_PR = 2;

  switch (ds) {
    case DS_WAVEFORM:
      {
        if (frame.length != 3) return out;
        final v = _low7(b2).clamp(0, 127);
        out.add(row(v, 'w'));
        return out;
      }

    case DS_SPO2:
      {
        if (frame.length == 4) {
          final lowBits = _low7(b2);
          final highBits = _low7(b3!);
          final spo2 = _spo2CombineToPercent(lowBits, highBits);
          out.add(row(spo2.toStringAsFixed(0), 'spo2'));
          _spo2LowPending = null;
          return out;
        } else if (frame.length == 3) {
          if (_spo2LowPending == null) {
            _spo2LowPending = _low7(b2);
            return out;
          } else {
            final hi = _low7(b2);
            final lo = _spo2LowPending ?? 0;
            final spo2 = _spo2CombineToPercent(lo, hi);
            out.add(row(spo2.toStringAsFixed(0), 'spo2'));
            _spo2LowPending = null;
            return out;
          }
        }
        return out;
      }

    case DS_PR:
      {
        if (frame.length != 3) return out;
        out.add(row(_prFrom(b1, b2), 'pr'));
        return out;
      }

    default:
      return out;
  }
}
