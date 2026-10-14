class AppUser {
  final String uid;
  final String name;
  final String role; // manager | agent | pos
  final String phone;
  final String? parentUid; // الوكيل->المدير ، نقطة البيع->الوكيل

  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    this.phone = '',
    this.parentUid,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: m['name'] ?? '',
        role: m['role'] ?? '',
        phone: m['phone'] ?? '',
        parentUid: m['parentUid'],
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role,
        'phone': phone,
        if (parentUid != null) 'parentUid': parentUid,
      };
}
