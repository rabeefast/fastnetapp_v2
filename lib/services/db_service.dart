import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../models/payment.dart';

/// طبقة الوصول لقاعدة Firestore.
/// ملاحظة: مكتبة Firestore تحتفظ بنسخة محلية تلقائيا (عمل دون اتصال)
/// وتدفع التغييرات فور عودة الاتصال — هذا أساس مبدأ "العمل المحلي ثم المزامنة".
class DbService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users => _db.collection('users');

  Future<List<AppUser>> childrenOf(String uid, String role) async {
    final s = await users.where('parentUid', isEqualTo: uid).where('role', isEqualTo: role).get();
    return s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  Future<void> addDelivery(Delivery d) =>
      _db.collection('deliveries').doc(d.id).set(d.toMap());

  Future<void> addPayment(Payment p) =>
      _db.collection('payments').doc(p.id).set(p.toMap());

  Stream<QuerySnapshot<Map<String, dynamic>>> deliveriesFor(String uid) => _db
      .collection('deliveries')
      .where('toUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> paymentsFor(String uid) => _db
      .collection('payments')
      .where('toUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  /// إجمالي ديون مستلم معين (تسليمات ناقصة سدادات)
  Future<double> debtOf(String uid) async {
    final dels = await _db.collection('deliveries').where('toUid', isEqualTo: uid).get();
    final pays = await _db.collection('payments').where('toUid', isEqualTo: uid).get();
    double d = 0, p = 0;
    for (final x in dels.docs) { d += (x.data()['totalAmount'] ?? 0).toDouble(); }
    for (final x in pays.docs) { p += (x.data()['amount'] ?? 0).toDouble(); }
    return d - p;
  }
}
