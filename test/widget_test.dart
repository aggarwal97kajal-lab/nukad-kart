import 'package:flutter_test/flutter_test.dart';
import 'package:nukad_kart/data/demo_data.dart';

void main() {
  test('4 main categories and 25 subcategories', () {
    expect(kCategories.length, 4);
    expect(kCategories.fold<int>(0, (s, c) => s + c.subs.length), 25);
    expect(kCategories[3].subs.last.name, 'Home & Pooja');
  });

  test('store prices never exceed MRP', () {
    for (final l in kListings) {
      expect(l.price <= productById(l.productId).mrp, isTrue);
    }
  });
}
