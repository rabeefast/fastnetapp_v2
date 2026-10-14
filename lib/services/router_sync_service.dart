import 'package:cloud_firestore/cloud_firestore.dart';

import 'router_api_service.dart';

class RouterSyncResult {
  final int totalCards, matched, used;
  RouterSyncResult(this.totalCards, this.matched, this.used);
}

/// مزامنة حالة الكروت من User Manager (disk1 على الراوتر) إلى التطبيق.
/// للمدير فقط — القراءة فقط، لا يُنشئ ولا يعدل أي ملف تعريف في الراوتر.
class RouterSyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<RouterSyncResult> sync(
    String managerUid,
    RouterApiClient client,
  ) async {
    final um = await client.fetchUmUsers();

    final batches = await _db
        .collection('batches')
        .where('managerUid', isEqualTo: managerUid)
        .get();
    var total = 0, matched = 0, used = 0;
    for (final b in batches.docs) {
      final cards =
          await _db.collection('cards').where('batchId', isEqualTo: b.id).get();
      var i = 0;
      while (i < cards.docs.length) {
        final w = _db.batch();
        final end = (i + 400 > cards.docs.length) ? cards.docs.length : i + 400;
        for (; i < end; i++) {
          final doc = cards.docs[i];
          total++;
          final attrs = um[doc.id];
          if (attrs == null) continue;
          matched++;
          final profile = attrs['actual-profile'] ?? '';
          final isUsed = profile.isNotEmpty && profile != 'null';
          if (isUsed) used++;
          w.update(doc.reference, {'um_used': isUsed, 'um_profile': profile});
        }
        await w.commit();
      }
    }
    return RouterSyncResult(total, matched, used);
  }
}
