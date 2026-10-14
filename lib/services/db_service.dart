import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../models/payment.dart';
import '../models/settings_model.dart';

/// طبقة الوصول لقاعدة Firestore (عمل دون اتصال مدمج عبر المكتبة).
/// كل الاستعلامات أحادية الحقل لتجنب الفهارس المركبة — الفلترة تتم محليًا.
class DbService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users => _db.collection('users');

  // ---- الحسابات ----
  Future<List<AppUser>> childrenOf(String uid, String role) async {
    final s = await users.where('parentUid', isEqualTo: uid).get();
    return s.docs
        .where((d) => d.data()['role'] == role)
        .map((d) => AppUser.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingRequests() =>
      _db.collection('requests').where('status', isEqualTo: 'pending').snapshots();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortByCreatedDesc(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    docs.sort((a, b) => (b.data()['createdAt'] ?? 0).compareTo(a.data()['createdAt'] ?? 0));
    return docs;
  }

  Future<void> approveRequest(String uid, Map<String, dynamic> req, String parentUid) async {
    await users.doc(uid).set({
      'name': req['name'] ?? '',
      'phone': req['phone'] ?? '',
      'role': req['role'] ?? 'agent',
      'parentUid': parentUid,
    });
    await _db.collection('requests').doc(uid).update({'status': 'approved'});
  }

  Future<void> rejectRequest(String uid) =>
      _db.collection('requests').doc(uid).update({'status': 'rejected'});

  // ---- الإعدادات ----
  Future<SettingsModel> loadSettings(String managerUid) async {
    final doc = await _db.collection('settings').doc(managerUid).get();
    if (doc.exists) return SettingsModel.fromMap(doc.data()!);
    final s = SettingsModel.defaults();
    await _db.collection('settings').doc(managerUid).set(s.toMap());
    return s;
  }

  // ---- الدفعات والكروت ----
  Future<String> createBatch({
    required String managerUid,
    required String name,
    required String categoryKey,
    required int firstSerial,
    required int count,
    required int firstCardNo,
  }) async {
    final bref = _db.collection('batches').doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    await bref.set({'managerUid': managerUid, 'name': name, 'categoryKey': categoryKey,
        'firstSerial': firstSerial, 'count': count, 'createdAt': now});
    var i = 0;
    while (i < count) {
      final w = _db.batch();
      final end = (i + 400 > count) ? count : i + 400;
      for (; i < end; i++) {
        final cref = _db.collection('cards').doc((firstCardNo + i).toString());
        w.set(cref, {'batchId': bref.id, 'categoryKey': categoryKey,
            'serial': firstSerial + i, 'status': 'inStock', 'createdAt': now});
      }
      await w.commit();
    }
    return bref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> batchesOf(String managerUid) =>
      _db.collection('batches').where('managerUid', isEqualTo: managerUid).snapshots();

  /// كل كروت الدفعة (id = رقم الكرت في User Manager، serial = الرقم التسلسلي)
  Future<List<Map<String, dynamic>>> batchCards(String batchId, String categoryKey) async {
    final s = await _db.collection('cards').where('batchId', isEqualTo: batchId).get();
    final list = s.docs
        .where((d) => d.data()['categoryKey'] == categoryKey && d.data()['status'] == 'inStock')
        .map((d) => {'id': d.id, 'serial': d.data()['serial'] as int})
        .toList();
    list.sort((a, b) => a['serial'].compareTo(b['serial']));
    return list;
  }

  /// مخزون مستلم في فئة معينة (كروت مسلّمة إليه)
  Future<int> stockCount(String uid, String categoryKey) async {
    final s = await _db.collection('cards').where('holderUid', isEqualTo: uid).get();
    return s.docs
        .where((d) => d.data()['categoryKey'] == categoryKey && d.data()['status'] == 'delivered')
        .length;
  }

  // ---- التسليم والسداد ----
  Future<void> addDelivery(Delivery d, List<String> cardIds, String holderUid) async {
    await _db.collection('deliveries').doc(d.id).set(d.toMap());
    var i = 0;
    while (i < cardIds.length) {
      final w = _db.batch();
      final end = (i + 400 > cardIds.length) ? cardIds.length : i + 400;
      for (; i < end; i++) {
        w.update(_db.collection('cards').doc(cardIds[i]),
            {'status': 'delivered', 'holderUid': holderUid});
      }
      await w.commit();
    }
  }

  Future<void> addPayment(Payment p) =>
      _db.collection('payments').doc(p.id).set(p.toMap());

  Stream<QuerySnapshot<Map<String, dynamic>>> deliveriesTo(String uid) =>
      _db.collection('deliveries').where('toUid', isEqualTo: uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> paymentsTo(String uid) =>
      _db.collection('payments').where('toUid', isEqualTo: uid).snapshots();

  Future<double> debtOf(String uid) async {
    final dels = await _db.collection('deliveries').where('toUid', isEqualTo: uid).get();
    final pays = await _db.collection('payments').where('toUid', isEqualTo: uid).get();
    double d = 0, p = 0;
    for (final x in dels.docs) { d += (x.data()['totalAmount'] ?? 0).toDouble(); }
    for (final x in pays.docs) { p += (x.data()['amount'] ?? 0).toDouble(); }
    return d - p;
  }
}
