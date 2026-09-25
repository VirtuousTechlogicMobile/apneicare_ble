import 'package:apneicare_ble/apneicare_ble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChecksumCalculator', () {
    test('addChecksum matches CMD+P1+P2', () {
      final cmd = [0x55, 0xAA, 0x48, 0x00, 0x00];
      final withSum = ChecksumCalculator.addChecksum(cmd);
      expect(withSum.length, 6);
      expect(withSum.last, 0x48);
      expect(ChecksumCalculator.validate(withSum), isTrue);
    });
  });

  group('parseRealtimePacketToCsvRows', () {
    setUp(resetRealtimePacketParser);

    test('parses 3-byte waveform', () {
      // status bit7=1, ds=0 waveform, value in b2 low7
      final rows = parseRealtimePacketToCsvRows([0x80, 0x00, 0x2A]);
      expect(rows.length, 1);
      expect(rows.first, startsWith('42,w,'));
    });

    test('parses 4-byte SpO2 V1.2', () {
      // spo2 98% → raw14 = 980 → high7=7, low7=84 (0x54)
      final rows = parseRealtimePacketToCsvRows([0x80, 0x01, 0x54, 0x07]);
      expect(rows.length, 1);
      expect(rows.first, '98,spo2,ON');
    });

    test('parses PR packet', () {
      // ds = 0x02 (PR), pr from b1 bit6 + b2
      final rows = parseRealtimePacketToCsvRows([0x80, 0x02, 0x48]);
      expect(rows.length, 1);
      expect(rows.first, contains(',pr,'));
    });

    test('rejects non-status first byte', () {
      final rows = parseRealtimePacketToCsvRows([0x00, 0x00, 0x2A]);
      expect(rows, isEmpty);
    });
  });

  group('ApneicareSample', () {
    test('fromCsvRow', () {
      final s = ApneicareSample.fromCsvRow('98,spo2,ON');
      expect(s.value, '98');
      expect(s.dataType, 'spo2');
      expect(s.probeStatus, 'ON');
    });
  });
}
