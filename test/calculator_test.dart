import 'package:flutter_test/flutter_test.dart';
import 'package:fastnet_app/core/calculator.dart';
import 'package:fastnet_app/models/category_config.dart';

void main() {
  group('الحساب المالي المعتمد من المدير', () {
    final c100 = CategoryConfig(
        key: 'c100', label: '100', umProfile: '100new',
        mgMode: 'page', mgPrice: 4250, agMode: 'page', agPrice: 4500,
        pageSize: 51, freePerPage: 1);
    final c250 = CategoryConfig(
        key: 'c250', label: '250', umProfile: '250new',
        mgMode: 'page', mgPrice: 10625, agMode: 'page', agPrice: 11250,
        pageSize: 51, freePerPage: 1);
    final c2500 = CategoryConfig(
        key: 'c2500', label: '2500', umProfile: '2500r',
        mgMode: 'card', mgPrice: 2125, agMode: 'card', agPrice: 2250);
    final c500 = CategoryConfig(
        key: 'c500', label: '500', umProfile: '500new',
        mgMode: 'page', mgPrice: 21250, agMode: 'card', agPrice: 450,
        pageSize: 51, freePerPage: 1);

    test('سعر الكرت الواحد من صفحة 100 للوكيل = 85', () {
      expect(DeliveryCalculator.unitMg(c100), 85.0);
    });
    test('صفحتان من فئة 100 للوكيل = 8500', () {
      expect(DeliveryCalculator.amountMg(c100, pages: 2), 8500.0);
    });
    test('صفحة 250 من المدير = 10625 ومن الوكيل لنقطة البيع = 11250', () {
      expect(DeliveryCalculator.amountMg(c250, pages: 1), 10625.0);
      expect(DeliveryCalculator.amountAg(c250, pages: 1), 11250.0);
    });
    test('الفئات بالتجزئة (2500) بلا كرت مجاني', () {
      expect(DeliveryCalculator.amountMg(c2500, cards: 10), 21250.0);
      expect(DeliveryCalculator.freeCardsFor(c2500, 3), 0);
    });
    test('500 للوكيل بالصفحة والوكيل يبيعها لنقطة البيع بالكرت', () {
      expect(DeliveryCalculator.amountMg(c500, pages: 1), 21250.0);
      expect(DeliveryCalculator.amountAg(c500, cards: 7), 3150.0);
    });
    test('حجم الصفحة مرن: صفحة 50 بلا مجاني تعطي سعر الكرت = السعر/50', () {
      final c = CategoryConfig(key: 'x', label: 'x', umProfile: 'x',
          mgMode: 'page', mgPrice: 5000, pageSize: 50, freePerPage: 0);
      expect(DeliveryCalculator.unitMg(c), 100.0);
    });
  });
}
