import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/settings_model.dart';

/// حالة المدير العامة: إعدادات الفئات والأسعار
class AppState extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  SettingsModel? settings;
  bool loading = false;

  Future<void> load(String managerUid) async {
    loading = true;
    notifyListeners();
    final doc = await _db.collection('settings').doc(managerUid).get();
    if (doc.exists) {
      settings = SettingsModel.fromMap(doc.data()!);
    } else {
      settings = SettingsModel.defaults();
      await _db.collection('settings').doc(managerUid).set(settings!.toMap());
    }
    loading = false;
    notifyListeners();
  }

  Future<void> save(String managerUid) async {
    if (settings == null) return;
    await _db.collection('settings').doc(managerUid).set(settings!.toMap());
    notifyListeners();
  }
}
