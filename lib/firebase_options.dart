// ============================================================
// ملف إعداد Firebase — تم تعبئته تلقائيًا من google-services.json
// المشروع: fast-net2
// لا تشارك هذا الملف علنًا — اتركه داخل مستودعك الخاص
// ============================================================
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBrPrWAhTKBjHeWadwUzz6Cc2efqSAIdA8',
    appId: '1:339836909590:android:f2a58b7fac1c9f5d4e1d37',
    messagingSenderId: '339836909590',
    projectId: 'fast-net2',
    storageBucket: 'fast-net2.firebasestorage.app',
  );

  static bool get isConfigured =>
      android.apiKey != 'PASTE_API_KEY' &&
      android.appId != 'PASTE_APP_ID' &&
      android.projectId != 'PASTE_PROJECT_ID';
}
