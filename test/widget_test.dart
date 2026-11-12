import 'package:flutter_test/flutter_test.dart';
import 'package:nukad_kart/services/bill.dart';
import 'package:nukad_kart/services/gstin.dart';
import 'package:nukad_kart/data/demo_data.dart';
import 'package:nukad_kart/state/app_state.dart';
import 'package:nukad_kart/state/thela_tracker.dart';
import 'package:nukad_kart/services/otp_service.dart';
import 'fixtures.dart';

void main() {
  setUp(seedDemo);

  test('4 main categories and 26 subcategories', () {
    expect(kCategories.length, 4);
    expect(kCategories.fold<int>(0, (s, c) => s + c.subs.length), 26);
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

  test('GST bill inside Delhi splits CGST and SGST; amount in words', () {
    final st = storeById('s1'); // GST (Regular)
    final rice = kProducts.firstWhere((p) => p.sub == 'Atta, rice & dal'); // 5 %
    final b = buildBill(
      store: st,
      orderId: 'NK-1',
      number: billNumber(st, DateTime(2026, 11, 12), 231),
      date: DateTime(2026, 11, 12),
      items: [(rice, 2, 105)],
      deliveryFee: 20,
      customerName: 'Priya',
      customerPhone: '9876543210',
      customerAddress: 'Rohini',
      customerState: 'Delhi',
    );
    expect(b.title, 'Tax Invoice');
    expect(b.number, 'SGS/26-27/000231');
    expect(b.interState, isFalse);
    expect(b.total, 230);
    expect((b.taxable + b.cgst + b.sgst - b.total).abs() < 0.02, isTrue);
    expect((b.cgst - b.sgst).abs() < 0.02, isTrue);
    expect(b.igst, 0);
    expect(amountInWords(230), 'Rupees Two Hundred Thirty Only');
    expect(amountInWords(125430.5), 'Rupees One Lakh Twenty Five Thousand Four Hundred Thirty and Fifty Paise Only');
  });

  test('other state uses IGST; shop without GST gives a Bill of Supply', () {
    final rice = kProducts.firstWhere((p) => p.sub == 'Atta, rice & dal');
    final inter = buildBill(
        store: storeById('s1'), orderId: 'NK-2', number: 'x', date: DateTime(2027, 2, 1), items: [(rice, 1, 105)],
        deliveryFee: 0, customerName: '', customerPhone: '', customerAddress: '', customerState: 'Haryana');
    expect(inter.interState, isTrue);
    expect(inter.cgst, 0);
    expect(inter.igst > 0, isTrue);
    expect(financialYear(DateTime(2027, 2, 1)), '26-27');
    expect(financialYear(DateTime(2027, 4, 1)), '27-28');
    final none = buildBill(
        store: storeById('s3'), orderId: 'NK-3', number: 'x', date: DateTime(2026, 11, 12), items: [(rice, 1, 105)],
        deliveryFee: 20, customerName: '', customerPhone: '', customerAddress: '', customerState: 'Delhi');
    expect(none.title, 'Bill of Supply');
    expect(none.cgst + none.sgst + none.igst, 0);
    expect(none.total, 125);
    expect(buildBill(
        store: storeById('s2'), orderId: 'NK-4', number: 'x', date: DateTime(2026, 11, 12), items: [(rice, 1, 105)],
        deliveryFee: 0, customerName: '', customerPhone: '', customerAddress: '', customerState: 'Delhi').note,
        contains('Composition'));
  });

  test('cart reminder: at most 2 a day, only while the shop is open', () {
    final s = AppState();
    final pid = kListings.firstWhere((l) => l.storeId == 's1' && l.stock > 0).productId;
    s.add('s1', pid); // Sharma: 8 am – 10 pm
    s.cartReminderTimes.clear(); // ignore the plan made from the real clock
    final noon = DateTime(2026, 11, 12, 12);
    final plan = s.cartReminderPlan(noon);
    expect(plan.first.$3, noon.add(const Duration(minutes: 30)));
    expect(plan.first.$1, contains('Sharma General Store'));
    int on(DateTime d) => plan.where((p) => p.$3.day == d.day).length;
    expect(on(noon), 2); // 12:30 and 4 pm
    expect(on(DateTime(2026, 11, 13)), 2); // 11 am and 6:30 pm
    expect(plan.length, 6);
    // 9:45 pm: +30 min and +4 h are after closing; next days still get 2 each.
    final late = s.cartReminderPlan(DateTime(2026, 11, 12, 21, 45));
    expect(late.where((p) => p.$3.day == 12), isEmpty);
    // Two already sent today: nothing more today.
    s.cartReminderTimes.addAll([DateTime(2026, 11, 12, 9), DateTime(2026, 11, 12, 11)]);
    expect(s.cartReminderPlan(noon).where((p) => p.$3.day == 12), isEmpty);
    // Empty cart: no reminders.
    s.remove(pid);
    expect(s.cartReminderPlan(noon), isEmpty);
  });

  test('GSTIN check and business buyer on the bill', () {
    expect(isValidGstin('27AAPFU0939F1ZV'), isTrue);
    expect(isValidGstin('27aapfu0939f1zv'), isTrue); // lower case typed
    expect(isValidGstin('27AAPFU0939F1ZA'), isFalse); // wrong check digit
    expect(isValidGstin('27AAPFU0939F1Z'), isFalse); // too short
    expect(isValidGstin(storeById('s1').gstin), isTrue);
    final rice = kProducts.firstWhere((p) => p.sub == 'Atta, rice & dal');
    BillGst g(String id) => storeById(id).gst;
    expect(g('s1'), BillGst.regular);
    final b = buildBill(
        store: storeById('s1'), orderId: 'NK-5', number: 'x', date: DateTime(2026, 11, 12), items: [(rice, 1, 105)],
        deliveryFee: 0, customerName: 'Rahul', customerPhone: '', customerAddress: '', customerState: 'Delhi',
        buyerGstin: '27AAPFU0939F1ZV', buyerBusiness: 'Rahul Traders');
    expect(b.buyerGstin, '27AAPFU0939F1ZV');
    expect(b.buyerBusiness, 'Rahul Traders');
    // No GST shop: business details are not printed (no credit to claim).
    final n = buildBill(
        store: storeById('s3'), orderId: 'NK-6', number: 'x', date: DateTime(2026, 11, 12), items: [(rice, 1, 105)],
        deliveryFee: 0, customerName: '', customerPhone: '', customerAddress: '', customerState: 'Delhi',
        buyerGstin: '27AAPFU0939F1ZV', buyerBusiness: 'Rahul Traders');
    expect(n.buyerGstin, '');
  });

  test('order rating is per order and separate from the store rating', () {
    final s = AppState();
    s.rateOrder('NK-1', const OrderRating(5, good: ['On time']));
    expect(s.orderRatings['NK-1']!.stars, 5);
    expect(s.orderRatings.containsKey('NK-2'), isFalse); // same shop, other order: not rated
    expect(s.shouldAskOrderRating('NK-2'), isTrue);
    expect(s.ratings.containsKey('s1'), isFalse); // store rating untouched
    s.rate('s1', 3);
    expect(s.orderRatings['NK-1']!.stars, 5);
    expect(s.orderRatings['NK-1']!.summary, 'On time');
  });

  test('at most 2 live orders at a time', () {
    final s = AppState();
    final pid = kListings.firstWhere((l) => l.storeId == 's1' && l.stock > 0).productId;
    for (var i = 0; i < 2; i++) {
      s.add('s1', pid);
      s.placeOrder(door: false);
    }
    expect(s.liveOrders.length, 2);
    expect(s.canPlaceAnotherOrder, isFalse);
    s.add('s1', pid);
    expect(() => s.placeOrder(door: false), throwsStateError);
    s.orders.first.status = OrderStatus.delivered; // one delivered: a new order is allowed
    expect(s.canPlaceAnotherOrder, isTrue);
  });

  test('cart shop not near the chosen address is not serviceable', () {
    final s = AppState();
    s.add('s1', 'p6');
    expect(s.serviceable, isTrue);
    kStores.removeWhere((x) => x.id == 's1'); // the new address has no Sharma General Store within 500 m
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

  test('thela status: standing, moving, was here, gone', () {
    final tr = ThelaTracker.instance..reset();
    Thela th(int seen, bool moving) =>
        Thela('t9', 'Ramu', 'Vegetables', 200, 0, true, true, '', seen, const [], lat: 28.7010, lng: 77.1010, moving: moving);
    tr.update(28.7, 77.1, [th(30, false)]);
    expect(tr.of('t9').status, ThelaStatus.standing);
    tr.update(28.7, 77.1, [th(10, true)]);
    expect(tr.of('t9').status, ThelaStatus.moving);
    tr.update(28.7, 77.1, [th(300, false)]);
    expect(tr.of('t9').status, ThelaStatus.wasHere);
    var back = '';
    tr.onBackInArea = (id) => back = id;
    tr.update(28.7, 77.1, []);
    expect(tr.of('t9').status, ThelaStatus.notAvailable);
    tr.update(28.7, 77.1, [th(5, false)]);
    expect(back, 't9');
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
