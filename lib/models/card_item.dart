/// كرت واحد من User Manager (الرقم الكبير = اسم المستخدم، بلا كلمة مرور)
class CardItem {
  final String id;        // username في User Manager
  final String batchId;
  final String categoryKey;
  final int serial;       // الرقم التسلسلي المطبوع
  String status;          // inStock | delivered | sold
  String? holderUid;      // الوكيل/نقطة البيع الحالية
  final DateTime createdAt;

  CardItem({
    required this.id,
    required this.batchId,
    required this.categoryKey,
    required this.serial,
    this.status = 'inStock',
    this.holderUid,
    required this.createdAt,
  });

  factory CardItem.fromMap(String id, Map<String, dynamic> m) => CardItem(
        id: id,
        batchId: m['batchId'] ?? '',
        categoryKey: m['categoryKey'] ?? '',
        serial: m['serial'] ?? 0,
        status: m['status'] ?? 'inStock',
        holderUid: m['holderUid'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] ?? 0),
      );

  Map<String, dynamic> toMap() => {
        'batchId': batchId,
        'categoryKey': categoryKey,
        'serial': serial,
        'status': status,
        if (holderUid != null) 'holderUid': holderUid,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
