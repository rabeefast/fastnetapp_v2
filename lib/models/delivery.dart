/// عملية تسليم واحدة (دفعة تسليم قد تضم أكثر من فئة)
class Delivery {
  final String id;
  final String fromUid;
  final String toUid;          // الوكيل أو نقطة البيع
  final String toName;
  final String batchId;
  final String side;           // 'mg' (مدير->وكيل) أو 'ag' (وكيل->نقطة بيع)
  final List<DeliveryItem> items;
  final double totalAmount;    // قيمة المديونية المولدة
  final DateTime createdAt;

  Delivery({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.toName,
    required this.batchId,
    required this.side,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
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
  final String type;   // 'pages' | 'cards'
  final int pages;     // إذا type == pages
  final List<int> cardSerials; // إذا type == cards (يدعم غير المتسلسل)
  final double amount;

  DeliveryItem({
    required this.categoryKey,
    required this.type,
    this.pages = 0,
    this.cardSerials = const [],
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'categoryKey': categoryKey,
        'type': type,
        'pages': pages,
        'cardSerials': cardSerials,
        'amount': amount,
      };
}
