// How-to video: a thela in the Partner app (demo server, tool/demo). Run only by demo-video.yml.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nukad_partner/main.dart' as app;
import 'package:nukad_partner/api.dart';
import 'tour_kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('thela tour', (t) async {
    final k = Tour(t);
    // Start offline with yesterday's prices, like a morning.
    await callApi('POST', '/v1/partner/live', kDemoToken, {'on': false});
    k.start();
    app.main();
    await k.hold(1500);
    k.dpr();

    // 1. Log in as a thela
    await k.onboard('Thela (moving)');
    await k.hold(1200);
    await k.tap(find.text('Continue with Google'), pause: 2500);

    // 2. Today's prices
    await k.wait(find.byType(Switch), secs: 40);
    step('prices');
    await k.hold(2000);
    if (k.has(find.text('Yes, same'))) await k.tap(find.text('Yes, same'), pause: 2000);
    await k.tap(find.text('Products').last, pause: 2500);
    await k.scroll(-300);
    await k.scroll(300);
    await k.tap(find.text('Home').last, pause: 1500);

    // 3. Go LIVE
    step('live');
    await k.tap(find.byType(Switch).first, pause: 2000);
    if (k.has(find.text('Go LIVE'))) await k.tap(find.text('Go LIVE'), pause: 2000);
    await k.wait(find.textContaining('LIVE'), secs: 20);
    await k.hold(3000);

    // 4. A customer calls you to their street (customer's phone, through the demo server)
    await callApi('POST', '/v1/partner/location', kDemoToken, {'lat': 28.590761, 'lng': 77.087272});
    await callApi('POST', '/v1/thelas/t_ramesh/call', customerToken,
        {'lat': 28.5895, 'lng': 77.0884, 'address': 'House 21, 1st floor, Gali no. 4, Palam'});
    step('call');
    await k.wait(find.text('Coming'), secs: 30);
    await k.hold(2500);
    await k.tap(find.text('Coming'), pause: 2500);

    // 5. The customer writes; you reply
    await callApi('POST', '/v1/me/chats/t_ramesh', customerToken, {'text': 'Bhaiya, 1 kg tamatar aur aadha kg bhindi le aana'});
    step('chat');
    await k.hold(2500);
    final open = find.textContaining('Messages').evaluate().isNotEmpty ? find.textContaining('Messages') : find.byIcon(Icons.chat_bubble_outline);
    await k.tap(open, pause: 2000);
    if (k.has(find.text('Open'))) await k.tap(find.text('Open'), pause: 1500);
    // The thela chat answers with one tap: ready-made replies (typing is there too, under "Type").
    await k.wait(find.textContaining('5 min mein aata'), secs: 20);
    await k.hold(1500);
    await k.tap(find.textContaining('5 min mein aata').last, pause: 3000);
    await t.pageBack();
    await k.hold(1000);
    if (!k.has(find.byType(Switch))) {
      await t.pageBack();
      await k.hold(1000);
    }

    // 6. Reached and sold
    step('sold');
    if (k.has(find.text('Reached, sold'))) await k.tap(find.text('Reached, sold'), pause: 2500);

    // 7. Going home: switch off
    step('offline');
    await k.tap(find.byType(Switch).first, pause: 3500);
    step('end');
  }, timeout: const Timeout(Duration(minutes: 50)));
}
