class ChecksumCalculator {
  static int calculate(List<int> data) {
    if (data.length < 3) return 0;
    final int cmd = data[2];
    final int p1 = data[3];
    final int p2 = data[4];
    return (cmd + p1 + p2) & 0xFF;
  }

  static bool validate(List<int> data) {
    if (data.length < 6) return false;
    final dataWithoutChecksum = data.sublist(0, data.length - 1);
    final calculated = calculate(dataWithoutChecksum);
    final received = data.last;
    return calculated == received;
  }

  static List<int> addChecksum(List<int> data) {
    int checksum = calculate(data);
    List<int> result = List.from(data);
    result.add(checksum);
    return result;
  }
}
