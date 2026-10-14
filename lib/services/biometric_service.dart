import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local app lock. Firebase remains the source of account identity;
/// this stores only an opt-in flag and never stores a password or token.
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static String _key(String uid) => 'biometric_enabled_${uid.trim()}';

  static Future<bool> isEnabled(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(uid)) ?? false;
  }

  static Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return false;
      }
      // Avoid getAvailableBiometrics here: Android only reports enrolled
      // biometric types reliably on API 29+, while this app also supports
      // fingerprint-capable phones on older Android releases.
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(String uid, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(uid), enabled);
  }
}
