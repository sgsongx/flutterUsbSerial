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
}
