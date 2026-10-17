import 'package:flutter_test/flutter_test.dart';

import '../lib/core/phone_auth_identifier.dart';

void main() {
  group('PhoneAuthIdentifier', () {
    test('ignores phone formatting consistently', () {
      expect(
        PhoneAuthIdentifier.emailForPhone('+967 777-123-456'),
        PhoneAuthIdentifier.emailForPhone('00967 (777) 123 456'),
      );
    });

    test('keeps legacy email sign-in identifiers unchanged', () {
      expect(
        PhoneAuthIdentifier.forLogin(' manager@example.com '),
        'manager@example.com',
      );
    });

    test('maps phone login to its internal auth identifier', () {
      expect(
        PhoneAuthIdentifier.forLogin('+967 777 123 456'),
        'phone_967777123456@fastnet.invalid',
      );
    });

    test('normalizes Arabic-Indic phone digits', () {
      expect(
        PhoneAuthIdentifier.emailForPhone('٩٦٧ ٧٧٧ ١٢٣ ٤٥٦'),
        'phone_967777123456@fastnet.invalid',
      );
    });
  });
}
