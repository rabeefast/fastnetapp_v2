import 'package:flutter_test/flutter_test.dart';
import 'package:fastnet_app/core/serial_parser.dart';

void main() {
  group('parseSerials', () {
    test('parses separated serials and inclusive ranges', () {
      expect(parseSerials('12, 14 16-18'), [12, 14, 16, 17, 18]);
    });

    test('returns an empty list for blank input', () {
      expect(parseSerials('  '), isEmpty);
    });

    test('rejects malformed and non-positive serials', () {
      expect(() => parseSerials('12,x'), throwsFormatException);
      expect(() => parseSerials('0'), throwsFormatException);
      expect(() => parseSerials('-2'), throwsFormatException);
    });

    test('rejects reversed, duplicate, and oversized ranges', () {
      expect(() => parseSerials('20-10'), throwsFormatException);
      expect(() => parseSerials('10,10'), throwsFormatException);
      expect(() => parseSerials('1-500'), throwsFormatException);
    });
  });
}
