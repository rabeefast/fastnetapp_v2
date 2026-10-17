/// Converts a phone identifier to a stable, non-deliverable Firebase Auth email.
///
/// Firebase Email/Password requires an email-shaped identifier even when the
/// product uses phone + password. This address is internal only; it is not an
/// inbox and cannot be used for email-based password recovery.
class PhoneAuthIdentifier {
  const PhoneAuthIdentifier._();

  static String normalize(String phone) {
    final digits = StringBuffer();
    for (final value in phone.runes) {
      if (value >= 0x30 && value <= 0x39) {
        digits.writeCharCode(value);
      } else if (value >= 0x0660 && value <= 0x0669) {
        digits.writeCharCode(value - 0x0660 + 0x30);
      } else if (value >= 0x06f0 && value <= 0x06f9) {
        digits.writeCharCode(value - 0x06f0 + 0x30);
      }
    }
    return digits.toString().replaceFirst(RegExp(r'^00'), '');
  }

  static String emailForPhone(String phone) =>
      'phone_${normalize(phone)}@fastnet.invalid';

  static String forLogin(String identifier) {
    final value = identifier.trim();
    return value.contains('@') ? value : emailForPhone(value);
  }
}
