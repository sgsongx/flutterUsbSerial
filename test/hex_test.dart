import 'package:flutter_test/flutter_test.dart';
import 'package:phone_comm/main.dart';

void main() {
  test('HEX input preserves exact bytes and rejects malformed input', () {
    expect(parseHex('01 a0\nFF'), [0x01, 0xA0, 0xFF]);
    expect(toHex(parseHex('00 FF')), '00 FF');
    expect(() => parseHex('0'), throwsFormatException);
    expect(() => parseHex('0G'), throwsFormatException);
  });

  test('text escapes preserve raw bytes', () {
    expect(encodeText(r'A\r\n\x00\\中', escapes: true),
        [65, 13, 10, 0, 92, 0xE4, 0xB8, 0xAD]);
    expect(encodeText(r'\n'), [92, 110]);
    expect(() => encodeText(r'\x0G', escapes: true), throwsFormatException);
    expect(() => encodeText('abc\\', escapes: true), throwsFormatException);
  });

  test('record lines use independent millisecond timestamps and safe names',
      () {
    final time = DateTime(2026, 9, 29, 7, 8, 9, 42);
    expect(formatTimestamp(time), '2026-09-29 07:08:09.042');
    expect(formatLogLine('RX', time, data: [0x31, 0x0A]),
        '2026-09-29 07:08:09.042 RX 31 0A  |  "1\\n"\n');
    expect(formatLogLine('TX', time, data: [0x41], includeTimestamp: false),
        'TX 41  |  "A"\n');
    expect(normalizeRecordFileName(' capture '), 'capture.txt');
    expect(() => normalizeRecordFileName('../other'), throwsFormatException);
    expect(() => normalizeRecordFileName(List.filled(100, 'a').join()),
        throwsFormatException);
  });
}
