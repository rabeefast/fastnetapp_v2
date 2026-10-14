import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../models/payment.dart';
import '../models/settings_model.dart';

/// طبقة الوصول لقاعدة Firestore (عمل دون اتصال مدمج عبر المكتبة).
class DbService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  // ---- الحسابات ----
  Future<List<AppUser>> childrenOf(String uid, String role) async {
    final s = await users
        .where('parentUid', isEqualTo: uid)
        .where('role', isEqualTo: role)
        .get();
    return s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingRequests() => _db
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots();

  Future<void> approveRequest(
      String uid, Map<String, dynamic> req, String parentUid) async {
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
    if (name.trim().isEmpty) {
      throw ArgumentError('اسم الدفعة مطلوب');
    }
    if (firstSerial < 1 || firstCardNo < 1 || count < 1) {
      throw ArgumentError('بيانات الدفعة يجب أن تكون أرقامًا موجبة');
    }
    if (count > 10000) {
      throw ArgumentError('لا يمكن إنشاء أكثر من 10000 كرت في دفعة واحدة');
    }
    final bref = _db.collection('batches').doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cards = _db.collection('cards');

    // document IDs are User Manager usernames; never overwrite cards from an
    // earlier batch when an overlapping range is entered by mistake.
    for (var start = 0; start < count; start += 200) {
      final end = (start + 200 > count) ? count : start + 200;
      final existing = await Future.wait([
        for (var i = start; i < end; i++)
          cards.doc((firstCardNo + i).toString()).get(),
      ]);
      if (existing.any((doc) => doc.exists)) {
        throw StateError('يوجد رقم كرت مستخدم مسبقًا؛ لم يتم إنشاء الدفعة');
      }
    }

    await bref.set({
      'managerUid': managerUid,
      'name': name.trim(),
      'categoryKey': categoryKey,
      'firstSerial': firstSerial,
      'count': count,
      'createdAt': now,
    });
    final createdIds = <String>[];
    try {
      var i = 0;
      while (i < count) {
        final w = _db.batch();
        final end = (i + 400 > count) ? count : i + 400;
        final chunkIds = <String>[];
        for (; i < end; i++) {
          final id = (firstCardNo + i).toString();
          final cref = cards.doc(id);
          chunkIds.add(id);
          w.set(cref, {
            'batchId': bref.id,
            'categoryKey': categoryKey,
            'serial': firstSerial + i,
            'status': 'inStock',
            'holderUid': managerUid,
            'createdAt': now,
          });
        }
        await w.commit();
        createdIds.addAll(chunkIds);
      }
    } catch (_) {
      // Best-effort rollback so a network failure does not leave a partial batch.
      for (var start = 0; start < createdIds.length; start += 400) {
        final end =
            (start + 400 > createdIds.length) ? createdIds.length : start + 400;
        final cleanup = _db.batch();
        for (final id in createdIds.sublist(start, end)) {
          cleanup.delete(cards.doc(id));
        }
        try {
          await cleanup.commit();
        } catch (_) {
          // Preserve and rethrow the original write failure.
        }
      }
      try {
        await bref.delete();
      } catch (_) {
        // Preserve and rethrow the original write failure.
      }
      rethrow;
    }
    return bref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> batchesOf(String managerUid) =>
      _db
          .collection('batches')
          .where('managerUid', isEqualTo: managerUid)
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<List<Map<String, dynamic>>> inStockCards(
      String batchId, String categoryKey, String holderUid) async {
    final batch = await _db.collection('batches').doc(batchId).get();
    final managerUid = batch.data()?['managerUid'] as String?;
    final cards = _db.collection('cards');
    final inStock = await cards
        .where('batchId', isEqualTo: batchId)
        .where('categoryKey', isEqualTo: categoryKey)
        .where('status', isEqualTo: 'inStock')
        .get();
    // يدعم كروت الوكيل/نقطة البيع التي أنشأتها النسخة السابقة.
    final delivered = await cards
        .where('batchId', isEqualTo: batchId)
        .where('categoryKey', isEqualTo: categoryKey)
        .where('status', isEqualTo: 'delivered')
        .where('holderUid', isEqualTo: holderUid)
        .get();
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ...inStock.docs.where((d) =>
          d.data()['holderUid'] == holderUid ||
          (d.data()['holderUid'] == null && managerUid == holderUid)),
      ...delivered.docs,
    ];
    final list = docs
        .map<Map<String, dynamic>>((d) => {
              'id': d.id,
              'serial': (d.data()['serial'] as num).toInt(),
            })
        .toList();
    list.sort((a, b) => (a['serial'] as int).compareTo(b['serial'] as int));
    return list;
  }

  Future<int> countCards(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  Future<int> stockCount(String uid, String categoryKey) async {
    final owned = <String>{};
    final cards = _db.collection('cards');
    final held = await cards
        .where('holderUid', isEqualTo: uid)
        .where('categoryKey', isEqualTo: categoryKey)
        .get();
    for (final d in held.docs) {
      if (d.data()['status'] == 'inStock' ||
          d.data()['status'] == 'delivered') {
        owned.add(d.id);
      }
    }

    // الكروت القديمة التي أُنشئت قبل إضافة holderUid تخص مدير الدفعة.
    final batches = await _db
        .collection('batches')
        .where('managerUid', isEqualTo: uid)
        .where('categoryKey', isEqualTo: categoryKey)
        .get();
    for (final batch in batches.docs) {
      final legacy = await cards
          .where('batchId', isEqualTo: batch.id)
          .where('categoryKey', isEqualTo: categoryKey)
          .where('status', isEqualTo: 'inStock')
          .get();
      for (final card in legacy.docs) {
        if (card.data()['holderUid'] == null) owned.add(card.id);
      }
    }
    return owned.length;
  }

  // ---- التسليم والسداد ----
  Future<void> addDelivery(
      Delivery d, List<String> cardIds, String holderUid) async {
    if (cardIds.isEmpty || cardIds.length > 499) {
      throw ArgumentError('يجب أن يحتوي التسليم على 1 إلى 499 كرتًا');
    }
    if (cardIds.toSet().length != cardIds.length) {
      throw ArgumentError('يوجد كرت مكرر ضمن التسليم');
    }
    // سجل التسليم وتحديث ملكية الكروت عملية واحدة، لتجنب المديونية بلا مخزون.
    final w = _db.batch();
    w.set(_db.collection('deliveries').doc(d.id), d.toMap());
    for (final id in cardIds) {
      w.update(_db.collection('cards').doc(id),
          {'status': 'delivered', 'holderUid': holderUid});
    }
    await w.commit();
  }

  Future<void> addPayment(Payment p) =>
      _db.collection('payments').doc(p.id).set(p.toMap());

  Stream<QuerySnapshot<Map<String, dynamic>>> deliveriesTo(String uid) => _db
      .collection('deliveries')
      .where('toUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> paymentsTo(String uid) => _db
      .collection('payments')
      .where('toUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Future<double> debtOf(String uid) async {
    final dels =
        await _db.collection('deliveries').where('toUid', isEqualTo: uid).get();
    // fromUid هو صاحب المديونية الذي يسدد؛ toUid هو المدير الذي يستلم.
    final pays =
        await _db.collection('payments').where('fromUid', isEqualTo: uid).get();
    double d = 0, p = 0;
    for (final x in dels.docs) {
      d += (x.data()['totalAmount'] ?? 0).toDouble();
    }
    for (final x in pays.docs) {
      p += (x.data()['amount'] ?? 0).toDouble();
    }
    return d - p;
  }
}
