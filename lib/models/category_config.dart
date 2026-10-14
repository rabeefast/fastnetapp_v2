/// إعداد فئة واحدة قابلة للتتبع.
/// mode: 'page' (بيع بالصفحات) أو 'card' (تجزئة بالكرت).
class CategoryConfig {
  String key;
  String label;          // الاسم الظاهر: 100 / 250 / ...
  String umProfile;      // الاسم في User Manager: 100new / 200New / 2500r ...
  String mgMode;         // مسار المدير->الوكيل
  double mgPrice;        // سعر الصفحة أو سعر الكرت حسب الوضع
  String agMode;         // مسار الوكيل->نقطة البيع
  double agPrice;
  int pageSize;          // كروت الصفحة (افتراضي 51 - مرن)
  int freePerPage;       // الكرت/كروت المجانية بعد كل صفحة

  CategoryConfig({
    required this.key,
    required this.label,
    required this.umProfile,
    this.mgMode = 'page',
    this.mgPrice = 0,
    this.agMode = 'page',
    this.agPrice = 0,
    this.pageSize = 51,
    this.freePerPage = 1,
  });

  factory CategoryConfig.fromMap(Map<String, dynamic> m) => CategoryConfig(
        key: m['key'] ?? '',
        label: m['label'] ?? '',
        umProfile: m['umProfile'] ?? '',
        mgMode: m['mgMode'] ?? 'page',
        mgPrice: (m['mgPrice'] ?? 0).toDouble(),
        agMode: m['agMode'] ?? 'page',
        agPrice: (m['agPrice'] ?? 0).toDouble(),
        pageSize: m['pageSize'] ?? 51,
        freePerPage: m['freePerPage'] ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'umProfile': umProfile,
        'mgMode': mgMode,
        'mgPrice': mgPrice,
        'agMode': agMode,
        'agPrice': agPrice,
        'pageSize': pageSize,
        'freePerPage': freePerPage,
      };

  /// الفئات الست الافتراضية المعتمدة (تخزن في disk1 بالأسماء المقابلة في User Manager)
  static List<CategoryConfig> defaults() => [
        CategoryConfig(key: 'c100', label: '100', umProfile: '100new', mgMode: 'page', mgPrice: 4250, agMode: 'page', agPrice: 4500),
        CategoryConfig(key: 'c200', label: '200', umProfile: '200New', mgMode: 'page', mgPrice: 8500, agMode: 'page', agPrice: 9000),
        CategoryConfig(key: 'c250', label: '250', umProfile: '250new', mgMode: 'page', mgPrice: 10625, agMode: 'page', agPrice: 11250),
        CategoryConfig(key: 'c500', label: '500', umProfile: '500new', mgMode: 'page', mgPrice: 21250, agMode: 'card', agPrice: 450),
        CategoryConfig(key: 'c1000', label: '1000', umProfile: '1000new', mgMode: 'card', mgPrice: 850, agMode: 'card', agPrice: 900),
        CategoryConfig(key: 'c2500', label: '2500', umProfile: '2500r', mgMode: 'card', mgPrice: 2125, agMode: 'card', agPrice: 2250),
      ];
}
