import 'category_config.dart';

class SettingsModel {
  List<CategoryConfig> categories;
  int lowStockThreshold; // حد تنبيه انخفاض المخزون (كروت)

  SettingsModel({required this.categories, this.lowStockThreshold = 20});

  factory SettingsModel.fromMap(Map<String, dynamic> m) => SettingsModel(
        categories: ((m['categories'] ?? []) as List)
            .map((e) => CategoryConfig.fromMap(e))
            .toList(),
        lowStockThreshold: m['lowStockThreshold'] ?? 20,
      );

  Map<String, dynamic> toMap() => {
        'categories': categories.map((e) => e.toMap()).toList(),
        'lowStockThreshold': lowStockThreshold,
      };

  factory SettingsModel.defaults() =>
      SettingsModel(categories: CategoryConfig.defaults());
}
