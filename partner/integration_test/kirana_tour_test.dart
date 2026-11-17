// How-to video: a kirana store in the Partner app (demo server, tool/demo). Run only by demo-video.yml.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nukad_partner/main.dart' as app;
import 'tour_kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('kirana tour', (t) async {
    final k = Tour(t);
    app.main();
    await k.hold(1500);
    k.dpr();

    // 1. Log in as a shop
    await k.wait(find.text('Continue with Google'), secs: 40);
    step('login');
    await k.hold(1500);
    if (k.has(find.text('Shop / kirana'))) await k.tap(find.text('Shop / kirana'), pause: 1000);
    await k.tap(find.text('Continue with Google'), pause: 2000);

    // 2. Home: the shop is live
    await k.wait(find.textContaining('LIVE'), secs: 40);
    step('home');
    await k.hold(3500);
    await k.scroll(-300);
    await k.scroll(300);

    // 3. Products and stock
    step('products');
    await k.tap(find.text('Products').last, pause: 2500);
    await k.scroll(-250);
    final sw = find.byType(Switch);
    if (k.has(sw)) {
      step('stock');
      await k.tap(sw.at(1), pause: 1500);
      await k.tap(sw.at(1), pause: 1500);
    }

    // 4. Ways to add products
    step('addways');
    await k.tap(find.byType(FloatingActionButton).evaluate().isNotEmpty ? find.byType(FloatingActionButton) : find.text('Add product'), pause: 3500);
    await t.pageBack().catchError((_) {});
    await k.hold(800);
    if (k.has(find.text('Scan barcode'))) {
      await t.tapAt(const Offset(200, 120));
      await k.hold(800);
    }

    // 5. A customer orders (customer's phone, through the demo server)
    await callApi('POST', '/v1/orders', customerToken, {
      'storeId': 's_gupta', 'door': true,
      'items': [{'id': 'pr_demo001', 'qty': 1}, {'id': 'pr_demo004', 'qty': 2}, {'id': 'pr_demo009', 'qty': 2}],
      'address': 'House 21, 1st floor, Gali no. 4, Palam, New Delhi 110045', 'state': 'Delhi',
      'lat': 28.5895, 'lng': 77.0884, 'name': 'Neha Sharma', 'phone': '9810000001',
    });
    step('neworder');
    await k.tap(find.text('Orders').last, pause: 2500);
    await k.wait(find.textContaining('#NK-'), secs: 30);
    await k.hold(1500);
    await k.tap(find.textContaining('#NK-'), pause: 2000);

    // 6. Accept
    step('accept');
    await k.tap(find.text('Accept'), pause: 2500);

    // 7. Pack: untick what you don't have, then Packed
    step('pack');
    await k.scroll(-200);
    await k.tap(find.byType(CheckboxListTile).at(2), pause: 1500);
    await k.tap(find.byType(CheckboxListTile).at(2), pause: 1200);
    await k.tap(find.text('Packed'), pause: 2500);

    // 8. Out for delivery
    step('out');
    await k.tap(find.text('Out for delivery'), pause: 3000);

    // 9. Customer's code, paid
    final mine = await callApi('GET', '/v1/me/orders', customerToken);
    final otp = '${((mine['orders'] as List).first as Map)['otp']}';
    step('code');
    await k.scroll(-300);
    await k.type(find.byType(TextField).last, otp);
    await k.tap(find.text('Paid cash'), pause: 3500);
    step('delivered');
    await k.hold(4000);
    step('end');
  }, timeout: const Timeout(Duration(minutes: 8)));
}

