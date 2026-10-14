import '../models/category_config.dart';

/// محرك الحساب المالي للتسليم.
/// القاعدة المعتمدة: الحساب المالي هو المرجع، وحجم الصفحة قابل للإعداد.
class DeliveryCalculator {
  /// سعر الكرت الواحد في مسار المدير -> الوكيل
  static double unitMg(CategoryConfig c) {
    if (c.mgMode == 'page') {
      final paid = c.pageSize - c.freePerPage;
      return paid > 0 ? c.mgPrice / paid : c.mgPrice;
    }
    return c.mgPrice;
  }

  /// سعر الكرت الواحد في مسار الوكيل -> نقطة البيع
  static double unitAg(CategoryConfig c) {
    if (c.agMode == 'page') {
      final paid = c.pageSize - c.freePerPage;
      return paid > 0 ? c.agPrice / paid : c.agPrice;
    }
    return c.agPrice;
  }

  /// قيمة تسليم مسار مدير->وكيل
  static double amountMg(CategoryConfig c, {int pages = 0, int cards = 0}) {
    return c.mgMode == 'page' ? pages * c.mgPrice : cards * c.mgPrice;
  }

  /// قيمة تسليم مسار وكيل->نقطة بيع
  static double amountAg(CategoryConfig c, {int pages = 0, int cards = 0}) {
    return c.agMode == 'page' ? pages * c.agPrice : cards * c.agPrice;
  }

  /// عدد الكروت المجانية المستحقة لعدد صفحات معين
  static int freeCardsFor(CategoryConfig c, int pages) => pages * c.freePerPage;
}
