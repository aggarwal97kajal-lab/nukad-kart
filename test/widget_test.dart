import 'package:flutter_test/flutter_test.dart';
import 'package:nukad_kart/data/demo_data.dart';
import 'package:nukad_kart/state/app_state.dart';
import 'package:nukad_kart/state/thela_tracker.dart';
import 'package:nukad_kart/services/otp_service.dart';

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
    s.markPhoneVerified();
    s.saveAddress(const Address(flat: 'Flat 12', area: 'Sector 21, Rohini', pin: '110086'));
    s.signOut();
    expect(s.name, '');
    expect(s.signIn('a@gmail.com'), isTrue);
    expect(s.name, 'Priya Sharma');
    expect(s.serviceable, isTrue);
  });

  test('profile from the server fills a fresh install', () {
    final s = AppState();
    s.signIn('b@gmail.com');
    s.apiToken = 'tok';
    s.applyServerProfile({
      'token': 'tok',
      'user': {'name': 'Rahul', 'phone': '9876500000', 'phoneVerified': true},
      'addresses': [
        {'id': 'x', 'label': 'Home', 'flat': 'B-4', 'floor': null, 'area': 'Sector 21, Rohini',
         'city': 'New Delhi', 'state': 'Delhi', 'country': 'India', 'pin': '110086', 'lat': 28.718, 'lng': 77.096}
      ],
      'profileComplete': true,
    });
    expect(s.profileComplete, isTrue);
    expect(s.current.flat, 'B-4');
    expect(s.current.floor, '');
    expect(s.current.lat, 28.718);
    s.signOut();
    expect(s.apiToken, '');
  });

  test('unknown pin code is not serviceable', () {
    final s = AppState();
    s.saveAddress(const Address(area: 'Uttam Nagar', pin: '110059'));
    expect(s.serviceable, isFalse);
  });

  test('cancel allowed only while placed or accepted; after accept it is a strike', () {
    final s = AppState();
    s.add('s1', 'p6');
    final o = s.placeOrder(door: true);
    expect(s.canCancel(o), isTrue);
    o.status = OrderStatus.accepted;
    s.cancelOrder(o);
    expect(o.status, OrderStatus.cancelled);
    expect(s.strikes, 1);
    s.add('s1', 'p6');
    final o2 = s.placeOrder(door: true);
    o2.status = OrderStatus.packed;
    expect(s.canCancel(o2), isFalse);
    s.dispose();
  });

  test('address label and Hindi search words', () {
    final a = Address.fromJson(const Address(area: 'Sector 7', pin: '110085', label: 'Mummy ka ghar').toJson());
    expect(a.label, 'Mummy ka ghar');
  });

  test('shop timings: open and closed', () {
    final balaji = storeById('s3'); // 9 am - 6 pm
    expect(balaji.isOpenAt(DateTime(2026, 11, 11, 10, 0)), isTrue);
    expect(balaji.isOpenAt(DateTime(2026, 11, 11, 19, 30)), isFalse);
    final gupta = storeById('s2'); // 6 am - 9:30 pm
    expect(gupta.isOpenAt(DateTime(2026, 11, 11, 21, 15)), isTrue);
    expect(gupta.isOpenAt(DateTime(2026, 11, 11, 21, 45)), isFalse);
  });

  test('thela status: here now, moving away, not available after the wait', () {
    final now = DateTime(2026, 11, 11, 18, 0, 0);
    final t = ThelaLive(300, 0);
    t.prev = 290;
    expect(ThelaTracker.statusFor(t, now), ThelaStatus.hereNow);
    t.prev = 470;
    t.d = 480; // past 400 m and getting further
    expect(ThelaTracker.statusFor(t, now), ThelaStatus.movingAway);
    t.prev = 490;
    t.d = 480; // past 400 m but coming closer
    expect(ThelaTracker.statusFor(t, now), ThelaStatus.hereNow);
    t.prev = 500;
    t.d = 520; // just left: wait before hiding
    expect(ThelaTracker.statusFor(t, now), ThelaStatus.movingAway);
    expect(ThelaTracker.statusFor(t, now.add(ThelaTracker.outsideGrace)), ThelaStatus.notAvailable);
  });

  test('delivered only with the right delivery code', () {
    final s = AppState();
    s.add('s1', 'p6');
    final o = s.placeOrder(door: true);
    o.status = OrderStatus.outForDelivery;
    o.otp = '4821';
    expect(s.verifyOtp(o, '1111'), isFalse);
    expect(o.status, OrderStatus.outForDelivery);
    expect(o.wrongOtpTries, 1);
    expect(s.verifyOtp(o, '4821'), isTrue);
    expect(o.status, OrderStatus.delivered);
    s.dispose();
  });

  test('demo OTP: only the sent code verifies', () async {
    final o = DemoOtpService();
    final id = await o.send('9876543210');
    expect(await o.verify(id, '000000'), o.debugCode(id) == '000000');
    expect(await o.verify(id, o.debugCode(id)!), isTrue);
  });
}
