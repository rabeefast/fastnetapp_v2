class Batch {
  final String id;
  final String managerUid;
  String name; // يشتق من تاريخ الاستيراد تلقائيا + قابل للتعديل
  final DateTime createdAt;

  Batch({
    required this.id,
    required this.managerUid,
    required this.name,
    required this.createdAt,
  });

  factory Batch.fromMap(String id, Map<String, dynamic> m) => Batch(
        id: id,
        managerUid: m['managerUid'] ?? '',
        name: m['name'] ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] ?? 0),
      );

  Map<String, dynamic> toMap() => {
        'managerUid': managerUid,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
