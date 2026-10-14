/// عملية تسليم واحدة (دفعة تسليم قد تضم أكثر من فئة)
class Delivery {
  final String id;
  final String managerUid;
  final String fromUid;
  final String toUid; // الوكيل أو نقطة البيع
  final String toName;
  final String batchId;
  final String side; // 'mg' (مدير->وكيل) أو 'ag' (وكيل->نقطة بيع)
  final List<DeliveryItem> items;
  final double totalAmount; // قيمة المديونية المولدة
  final DateTime createdAt;

  Delivery({
    required this.id,
    this.managerUid = '',
    required this.fromUid,
    required this.toUid,
    required this.toName,
    required this.batchId,
    required this.side,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
  });

  factory Delivery.fromMap(String id, Map<String, dynamic> m) => Delivery(
        id: id,
        managerUid: m['managerUid'] ?? '',
        fromUid: m['fromUid'] ?? '',
        toUid: m['toUid'] ?? '',
        toName: m['toName'] ?? '',
        batchId: m['batchId'] ?? '',
        side: m['side'] ?? 'mg',
        items: ((m['items'] ?? []) as List)
            .map((e) => DeliveryItem.fromMap(e))
            .toList(),
        totalAmount: ((m['totalAmount'] ?? 0) as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          ((m['createdAt'] ?? 0) as num).toInt(),
        ),
      );

  Map<String, dynamic> toMap() => {
        if (managerUid.isNotEmpty) 'managerUid': managerUid,
        'fromUid': fromUid,
        'toUid': toUid,
        'toName': toName,
        'batchId': batchId,
        'side': side,
        'items': items.map((e) => e.toMap()).toList(),
        'totalAmount': totalAmount,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}

class DeliveryItem {
  final String categoryKey;
  final String type; // 'pages' | 'cards'
  final int pages; // إذا type == pages
  final List<int> cardSerials; // إذا type == cards (يدعم غير المتسلسل)
  final double amount;

  DeliveryItem({
    required this.categoryKey,
    required this.type,
    this.pages = 0,
    this.cardSerials = const [],
    required this.amount,
  });

  factory DeliveryItem.fromMap(Map<String, dynamic> m) => DeliveryItem(
        categoryKey: m['categoryKey'] ?? '',
        type: m['type'] ?? 'pages',
        pages: ((m['pages'] ?? 0) as num).toInt(),
        cardSerials: ((m['cardSerials'] ?? []) as List)
            .map((e) => (e as num).toInt())
            .toList(),
        amount: ((m['amount'] ?? 0) as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'categoryKey': categoryKey,
        'type': type,
        'pages': pages,
        'cardSerials': cardSerials,
        'amount': amount,
      };
}
