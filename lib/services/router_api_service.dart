/// خدمة الاتصال بالراوتر (MikroTik RouterOS 6 - User Manager على disk1).
///
/// المرحلة الأولى: إعدادات الاتصال فقط.
/// المرحلة الثانية: تنفيذ بروتوكول RouterOS API (قراءة فقط بمجموعة fastnet-read)
/// لجلب حالة الكروت من /tool user-manager user.
///
/// القيود المعتمدة:
/// - الاتصال بالراوتر يقتصر على حساب المدير فقط.
/// - وكيل ونقطة البيع لا يتصلان بالراوتر إطلاقا.
/// - القراءة فقط: لا ينشئ التطبيق ولا يعدل أي ملف تعريف.
class RouterApiService {
  String host;
  int port;
  String username;
  String password;

  RouterApiService({
    this.host = '10.10.1.1',
    this.port = 8728,
    this.username = 'fastnetapi',
    this.password = '',
  });

  bool get isConfigured => host.isNotEmpty && username.isNotEmpty;

  /// TODO(Phase 2): فتح قناة TCP للـ API وإرسال تجزئة بروتوكول RouterOS.
  Future<bool> testConnection() async {
    // ستنفذ في المرحلة الثانية مع فحص /system resource
    return isConfigured;
  }
}
