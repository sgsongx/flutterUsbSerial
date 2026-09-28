import 'package:flutter_test/flutter_test.dart';
import 'package:phone_comm/main.dart';

void main() {
  test('HEX input preserves exact bytes and rejects malformed input', () {
    expect(parseHex('01 a0\nFF'), [0x01, 0xA0, 0xFF]);
    expect(toHex(parseHex('00 FF')), '00 FF');
    expect(() => parseHex('0'), throwsFormatException);
    expect(() => parseHex('0G'), throwsFormatException);
  });
}
