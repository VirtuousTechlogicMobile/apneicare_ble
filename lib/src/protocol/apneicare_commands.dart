import 'checksum_calculator.dart';

class ApneicareCommands {
  static const int CMD_SYNCHRONIZE = 0xFD;
  static const int CMD_QUERY = 0xFE;
  static const int CMD_TRANSFER_DATA = 0xFA;
  static const int CMD_CLEAR = 0xF4;
  static const int CMD_EXIT_SYNC = 0xF3;
  static const int CMD_TIME_UPLOAD = 0xF6;
  static const int CMD_TIME_SETTING = 0xF7;
  static const int CMD_TIME_SETTING_ALT = 0xF8;
  static const int CMD_BATTERY_UPLOAD = 0x60;
  static const int CMD_PROBE_STATUS = 0x61;
  static const int CMD_REALTIME_START = 0x48;
  static const int CMD_REALTIME_STOP = 0x54;

  static const List<int> HEADER = [0x55, 0xAA];

  static List<int> realTimeStart() {
    final cmd = [...HEADER, CMD_REALTIME_START, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  static List<int> realTimeStop() {
    final cmd = [...HEADER, CMD_REALTIME_STOP, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  static List<int> timeUpload() {
    final cmd = [...HEADER, CMD_TIME_UPLOAD, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  static List<int> synchronize() {
    final cmd = [...HEADER, CMD_SYNCHRONIZE, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  static List<int> batteryUpload() {
    final cmd = [...HEADER, CMD_BATTERY_UPLOAD, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  static List<int> probeStatus() {
    final cmd = [...HEADER, CMD_PROBE_STATUS, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  static List<int> ping() {
    final cmd = [...HEADER, CMD_QUERY, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(cmd);
  }

  /// Protocol: 0x55 0xAA 0xF4 P1 P2 SUM
  static List<int> clear() {
    List<int> command = [...HEADER, CMD_CLEAR, 0x00, 0x00];
    return ChecksumCalculator.addChecksum(command);
  }
}
