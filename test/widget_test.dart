import 'package:flutter_test/flutter_test.dart';
import 'package:nukad_kart/data/demo_data.dart';
import 'package:nukad_kart/state/app_state.dart';

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

  test('delivery fee: ₹20 below ₹199 for door delivery, free from ₹199 or pickup', () {
    final s = AppState();
    expect(s.deliveryFeeFor(179, true), 20);
    expect(s.deliveryFeeFor(199, true), 0);
    expect(s.deliveryFeeFor(120, false), 0);
  });

  test('re-login with the same Google account skips the details', () {
    final s = AppState();
    expect(s.signIn('a@gmail.com'), isFalse);
    s.saveProfile('Priya Sharma', '9876543210');
    s.saveAddress(const Address(flat: 'Flat 12', area: 'Sector 21, Rohini', pin: '110086'));
    s.signOut();
    expect(s.name, '');
    expect(s.signIn('a@gmail.com'), isTrue);
    expect(s.name, 'Priya Sharma');
    expect(s.serviceable, isTrue);
  });

  test('unknown pin code is not serviceable', () {
    final s = AppState();
    s.saveAddress(const Address(area: 'Uttam Nagar', pin: '110059'));
    expect(s.serviceable, isFalse);
  });
}
