import 'package:fastnet_app/core/serial_parser.dart';

void _expectFailure(String input) {
  try {
    parseSerials(input);
  } on FormatException {
    return;
  }
  throw StateError('Expected invalid input to be rejected: $input');
}

void main() {
  final actual = parseSerials('12, 14 16-18');
  const expected = [12, 14, 16, 17, 18];
  if (actual.length != expected.length ||
      List.generate(actual.length, (i) => actual[i] == expected[i])
          .contains(false)) {
    throw StateError('Serial parsing returned $actual instead of $expected');
  }
  if (parseSerials('  ').isNotEmpty) {
    throw StateError('Blank input should return an empty list');
  }

  for (final invalid in ['12,x', '0', '-2', '20-10', '10,10', '1-500']) {
    _expectFailure(invalid);
  }
}
