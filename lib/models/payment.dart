/// سداد من المستلم (وكيل/نقطة بيع) — يخصم من المديونية
class Payment {
  final String id;
  final String fromUid;
  final String toUid;
  final double amount;
  final String note;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'amount': amount,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
