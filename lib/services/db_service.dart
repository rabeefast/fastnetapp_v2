import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../models/payment.dart';
import '../models/settings_model.dart';
import 'pdf_card_import_service.dart';

/// طبقة الوصول لقاعدة Firestore (عمل دون اتصال مدمج عبر المكتبة).
class DbService {
  // Firestore transactions are capped at 500 writes. Keep room for the batch
  // metadata document in the first transaction, while letting common imports
  // (including 255-card PDFs) commit atomically instead of leaving a stranded
  // "importing" batch if the app is interrupted.
  static const int _pdfImportChunkSize = 400;

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
    String uid,
    Map<String, dynamic> req,
    String parentUid,
  ) async {
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
    final lastSerial = firstSerial + count - 1;
    final lastUsername = (firstCardNo + count - 1).toString();
    if (lastSerial > 9999999 ||
        firstCardNo.toString().length < 8 ||
        lastUsername.length > 14) {
      throw ArgumentError(
        'الرقم التسلسلي يجب ألا يتجاوز 7 أرقام، واسم المستخدم من 8 إلى 14 رقمًا',
      );
    }
    final bref = _db.collection('batches').doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cards = _db.collection('cards');

    final batchData = <String, dynamic>{
      'managerUid': managerUid,
      'name': name.trim(),
      'categoryKey': categoryKey,
      'categoryKeys': [categoryKey],
      'firstSerial': firstSerial,
      'count': count,
      'createdAt': now,
      'importStatus': 'importing',
    };
    final attemptedIds = <String>[];
    try {
      await bref.set(batchData);
      for (var start = 0; start < count; start += 400) {
        final end = (start + 400 > count) ? count : start + 400;
        final ids = [
          for (var i = start; i < end; i++) (firstCardNo + i).toString(),
        ];
        attemptedIds.addAll(ids);
        await _db.runTransaction((transaction) async {
          final refs = ids.map((id) => cards.doc(id)).toList();
          final existing = <DocumentSnapshot<Map<String, dynamic>>>[];
          for (final ref in refs) {
            existing.add(await transaction.get(ref));
          }
          if (existing.any((doc) => doc.exists)) {
            throw StateError(
              'يوجد رقم كرت مستخدم مسبقًا؛ لم يتم استبدال أي كرت',
            );
          }
          for (var offset = 0; offset < refs.length; offset++) {
            transaction.set(refs[offset], {
              'batchId': bref.id,
              'categoryKey': categoryKey,
              'serial': firstSerial + start + offset,
              'status': 'inStock',
              'holderUid': managerUid,
              'createdAt': now,
            });
          }
        });
      }
      await bref.update({'importStatus': 'ready'});
    } catch (_) {
      var rollbackComplete = true;
      for (var start = 0; start < attemptedIds.length; start += 200) {
        final end = (start + 200 > attemptedIds.length)
            ? attemptedIds.length
            : start + 200;
        try {
          final existing = await Future.wait(
            attemptedIds.sublist(start, end).map((id) => cards.doc(id).get()),
          );
          final cleanup = _db.batch();
          var deletions = 0;
          for (final doc in existing) {
            if (doc.data()?['batchId'] == bref.id) {
              cleanup.delete(doc.reference);
              deletions++;
            }
          }
          if (deletions > 0) await cleanup.commit();
        } catch (_) {
          rollbackComplete = false;
        }
      }
      if (rollbackComplete) {
        try {
          await bref.delete();
        } catch (_) {
          // A surviving importStatus=importing batch remains hidden.
        }
      }
      rethrow;
    }
    return bref.id;
  }

  /// Imports several PDFs into one logical batch. Each PDF can map to a
  /// different category, while each card keeps its own username, serial and
  /// source page. Existing User Manager usernames are never overwritten.
  Future<String> createPdfBatch({
    required String managerUid,
    required String name,
    required List<ParsedPdfCards> files,
    required Map<String, String> categoryByFile,
    required Map<String, String> categoryLabelByKey,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (name.trim().isEmpty || files.isEmpty) {
      throw ArgumentError('اسم الدفعة وملف PDF واحد على الأقل مطلوبان');
    }

    final fileNames = files.map((file) => file.fileName).toList();
    if (fileNames.toSet().length != fileNames.length) {
      throw ArgumentError('يوجد ملفان بالاسم نفسه؛ أعد تسميتهما قبل الاستيراد');
    }
    if (files.any(
      (file) =>
          file.cards.isEmpty || !categoryByFile.containsKey(file.fileName),
    )) {
      throw ArgumentError('حدد فئة صحيحة لكل ملف PDF');
    }
    if (categoryByFile.values.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('الفئة المختارة غير صالحة؛ اختر فئة لكل ملف.');
    }

    final records = files.expand((file) => file.cards).toList();
    if (records.isEmpty || records.length > maxPdfImportCardsPerBatch) {
      throw ArgumentError('عدد الكروت يجب أن يكون بين 1 و7000');
    }
    final seen = <String>{};
    for (final record in records) {
      if (!RegExp(r'^\d{8,14}$').hasMatch(record.username)) {
        throw FormatException(
          'اسم مستخدم غير صالح في الصفحة ${record.pageNumber}.',
        );
      }
      if (record.serial < 1 || record.serial > 9999999) {
        throw FormatException(
          'رقم تسلسلي خارج النطاق في الصفحة ${record.pageNumber}.',
        );
      }
      if (!seen.add(record.username)) {
        throw StateError(
          'تكرر اسم مستخدم بين ملفات الدفعة؛ أزل التكرار قبل المتابعة.',
        );
      }
    }

    final cards = _db.collection('cards');
    final batchRef = _db.collection('batches').doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final categoryKeys =
        files.map((file) => categoryByFile[file.fileName]!).toSet().toList();
    final pageCount = files.fold<int>(0, (sum, file) => sum + file.pageCount);

    final batchData = <String, dynamic>{
      'managerUid': managerUid,
      'name': name.trim(),
      'categoryKeys': categoryKeys,
      'categoryLabels':
          categoryKeys.map((key) => categoryLabelByKey[key] ?? key).toList(),
      if (categoryKeys.length == 1) 'categoryKey': categoryKeys.single,
      'fileNames': fileNames,
      'fileCount': files.length,
      'pageCount': pageCount,
      'count': records.length,
      'createdAt': now,
    };

    final attemptedIds = <String>[];
    try {
      var completed = 0;
      while (completed < records.length) {
        final end = (completed + _pdfImportChunkSize > records.length)
            ? records.length
            : completed + _pdfImportChunkSize;
        final group = records.sublist(completed, end);
        final isFirstChunk = completed == 0;
        final isLastChunk = end == records.length;
        attemptedIds.addAll(group.map((record) => record.username));
        await _db.runTransaction((transaction) async {
          final refs = group
              .map((record) => cards.doc(record.username))
              .toList();
          // Keep transaction reads serial. A Transaction is a single mutable
          // operation context; concurrent method-channel reads against the same
          // transaction can fail on some FlutterFire/Android combinations.
          final existing = <DocumentSnapshot<Map<String, dynamic>>>[];
          for (final ref in refs) {
            existing.add(await transaction.get(ref));
          }
          if (existing.any((doc) => doc.exists)) {
            throw StateError(
              'يوجد اسم مستخدم موجود مسبقًا في التطبيق؛ لم يتم استبدال أي كرت.',
            );
          }
          // Create the batch header in the same transaction as the first card
          // writes. If the device is offline or this transaction fails, there
          // is no orphan "importing" document left in Firestore.
          if (isFirstChunk) {
            transaction.set(batchRef, {
              ...batchData,
              'importStatus': isLastChunk ? 'ready' : 'importing',
            });
          } else if (isLastChunk) {
            transaction.update(batchRef, {'importStatus': 'ready'});
          }
          for (var i = 0; i < group.length; i++) {
            final record = group[i];
            final categoryKey = categoryByFile[record.fileName]!;
            transaction.set(refs[i], {
              'batchId': batchRef.id,
              'categoryKey': categoryKey,
              'categoryLabel': categoryLabelByKey[categoryKey] ?? categoryKey,
              'serial': record.serial,
              'pageNumber': record.pageNumber,
              'sourcePdf': record.fileName,
              'status': 'inStock',
              'holderUid': managerUid,
              'createdAt': now,
            });
          }
        });
        completed = end;
        onProgress?.call(completed, records.length);
      }

      return batchRef.id;
    } catch (_) {
      // Only remove records that still belong to this import. This also
      // handles a timed-out commit whose server outcome was not reported.
      var rollbackComplete = true;
      for (var start = 0; start < attemptedIds.length; start += 200) {
        final end = (start + 200 > attemptedIds.length)
            ? attemptedIds.length
            : start + 200;
        final ids = attemptedIds.sublist(start, end);
        try {
          final existing = await Future.wait(
            ids.map((id) => cards.doc(id).get()),
          );
          final cleanup = _db.batch();
          var deletions = 0;
          for (final doc in existing) {
            if (doc.data()?['batchId'] == batchRef.id) {
              cleanup.delete(doc.reference);
              deletions++;
            }
          }
          if (deletions > 0) await cleanup.commit();
        } catch (_) {
          // Keep the batch marked importing so the app will not expose
          // incomplete stock if cleanup cannot reach Firestore.
          rollbackComplete = false;
        }
      }
      if (rollbackComplete) {
        try {
          await batchRef.delete();
        } catch (_) {
          // If deletion fails, importStatus=importing keeps partial rows hidden.
        }
      }
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> batchesOf(String managerUid) =>
      _db
          .collection('batches')
          .where('managerUid', isEqualTo: managerUid)
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<List<Map<String, dynamic>>> cardsInBatch(String batchId) async {
    final snapshot = await _db
        .collection('cards')
        .where('batchId', isEqualTo: batchId)
        .get();
    final cards = snapshot.docs
        .map((doc) => <String, dynamic>{'username': doc.id, ...doc.data()})
        .toList();
    cards.sort((a, b) {
      final pageA = (a['pageNumber'] as num?)?.toInt() ?? 0;
      final pageB = (b['pageNumber'] as num?)?.toInt() ?? 0;
      final pageOrder = pageA.compareTo(pageB);
      if (pageOrder != 0) return pageOrder;
      final serialA = (a['serial'] as num?)?.toInt() ?? 0;
      final serialB = (b['serial'] as num?)?.toInt() ?? 0;
      return serialA.compareTo(serialB);
    });
    return cards;
  }

  Future<List<Map<String, dynamic>>> inStockCards(
    String batchId,
    String categoryKey,
    String holderUid,
  ) async {
    final batch = await _db.collection('batches').doc(batchId).get();
    if (batch.data()?['importStatus'] == 'importing') return [];
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
      ...inStock.docs.where(
        (d) =>
            d.data()['holderUid'] == holderUid ||
            (d.data()['holderUid'] == null && managerUid == holderUid),
      ),
      ...delivered.docs,
    ];
    final list = docs
        .map<Map<String, dynamic>>(
          (d) => {'id': d.id, 'serial': (d.data()['serial'] as num).toInt()},
        )
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

    // A PDF batch stays hidden while chunked Firestore writes are in flight.
    final batchIds = held.docs
        .map((doc) => doc.data()['batchId'])
        .whereType<String>()
        .toSet()
        .toList();
    final batchSnapshots = await Future.wait(
      batchIds.map((id) => _db.collection('batches').doc(id).get()),
    );
    final importing = <String>{
      for (final batch in batchSnapshots)
        if (batch.data()?['importStatus'] == 'importing') batch.id,
    };
    for (final doc in held.docs) {
      if (importing.contains(doc.data()['batchId'])) owned.remove(doc.id);
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
    Delivery d,
    List<String> cardIds,
    String holderUid,
  ) async {
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
      w.update(_db.collection('cards').doc(id), {
        'status': 'delivered',
        'holderUid': holderUid,
      });
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

  /// Marks a selected set of cards sold only if every serial is still held
  /// by this user; partial sales are rejected.
  Future<int> markSold(String uid, List<int> serials) async {
    final wanted = serials.toSet();
    if (wanted.isEmpty || wanted.length > 499 || wanted.any((n) => n <= 0)) {
      throw ArgumentError('أدخل من 1 إلى 499 رقمًا تسلسليًا موجبًا');
    }
    if (wanted.length != serials.length) {
      throw ArgumentError('لا تكرر الرقم التسلسلي نفسه');
    }

    final snapshot =
        await _db.collection('cards').where('holderUid', isEqualTo: uid).get();
    final targets = snapshot.docs.where((doc) {
      final data = doc.data();
      final serial = data['serial'];
      return data['status'] == 'delivered' &&
          serial is num &&
          wanted.contains(serial.toInt());
    }).toList();

    if (targets.length != wanted.length) {
      throw StateError('بعض الأرقام غير موجودة في مخزونك أو سبق بيعها');
    }
    final targetSerials =
        targets.map((d) => (d.data()['serial'] as num).toInt()).toSet();
    if (targetSerials.length != wanted.length) {
      throw StateError(
        'يوجد تسلسل مكرر في دفعات مختلفة؛ لا يمكن تحديد الكرت بدقة',
      );
    }

    final soldAt = DateTime.now().millisecondsSinceEpoch;
    // Re-read every target inside the transaction so two devices cannot sell
    // the same card after independently observing the earlier "delivered"
    // state. Keep below Firestore's 500-write transaction limit.
    await _db.runTransaction((transaction) async {
      final currentDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final target in targets) {
        currentDocs.add(await transaction.get(target.reference));
      }
      for (final doc in currentDocs) {
        final data = doc.data();
        final serial = data?['serial'];
        if (!doc.exists ||
            data == null ||
            data['holderUid'] != uid ||
            data['status'] != 'delivered' ||
            serial is! num ||
            !wanted.contains(serial.toInt())) {
          throw StateError('تغير المخزون أثناء البيع؛ أعد المحاولة');
        }
      }
      for (final doc in currentDocs) {
        transaction.update(doc.reference, {
          'status': 'sold',
          'soldAt': soldAt,
        });
      }
    });
    return targets.length;
  }

  /// Streams new manager-wide history plus older manager-origin deliveries.
  Stream<List<Delivery>> deliveriesForManager(String managerUid) {
    final controller = StreamController<List<Delivery>>();
    final current = <String, Map<String, dynamic>>{};
    final legacy = <String, Map<String, dynamic>>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? currentSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? legacySub;

    void emit() {
      final merged = <String, Map<String, dynamic>>{...legacy, ...current};
      final items = merged.entries
          .map((entry) => Delivery.fromMap(entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(items);
    }

    void replace(
      Map<String, Map<String, dynamic>> target,
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      target
        ..clear()
        ..addEntries(snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())));
      emit();
    }

    currentSub = _db
        .collection('deliveries')
        .where('managerUid', isEqualTo: managerUid)
        .snapshots()
        .listen(
          (snapshot) => replace(current, snapshot),
          onError: controller.addError,
        );
    legacySub = _db
        .collection('deliveries')
        .where('fromUid', isEqualTo: managerUid)
        .snapshots()
        .listen(
          (snapshot) => replace(legacy, snapshot),
          onError: controller.addError,
        );
    controller.onCancel = () async {
      await currentSub?.cancel();
      await legacySub?.cancel();
    };
    return controller.stream;
  }
}
