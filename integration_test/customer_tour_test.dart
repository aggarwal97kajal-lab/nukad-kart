// How-to video: the customer app, driven like a person would use it, against the local demo server (tool/demo).
// Run only by .github/workflows/demo-video.yml. It prints NKSTEP / NKTAP lines; the video is cut and captioned from them.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:nukad_kart/main.dart' as app;
import 'package:nukad_kart/config/keys.dart';

const shopToken = String.fromEnvironment('SHOP_TOKEN');
const thelaToken = String.fromEnvironment('THELA_TOKEN');

/// Slow motion: animations run this many times slower and the video is sped up as much (smooth on the slow emulator).
const slow = 4;

int ms() => DateTime.now().millisecondsSinceEpoch;
void step(String id) => print('NKSTEP|$id|${ms()}');

Future<Map<String, dynamic>> callApi(String method, String path, String token, [Map<String, dynamic>? body]) async {
  final req = http.Request(method, Uri.parse('$apiBase$path'))
    ..headers['authorization'] = 'Bearer $token'
    ..headers['content-type'] = 'application/json';
  if (body != null) req.body = jsonEncode(body);
  final res = await http.Response.fromStream(await req.send());
  print('NKAPI|$method $path|${res.statusCode}');
  return res.body.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(res.body) as Map);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('customer tour', (t) async {
    Future<void> hold(int milli) async {
      final end = ms() + milli * slow;
      while (ms() < end) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    void dump(String why) {
      final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '').where((s) => s.trim().isNotEmpty).toSet();
      print('NKDUMP|$why|${texts.join(' ¦ ')}');
    }

    Future<Finder> wait(Finder f, {int secs = 25}) async {
      final end = ms() + secs * 1000 * slow;
      while (ms() < end) {
        await t.pump(const Duration(milliseconds: 100));
        if (f.evaluate().isNotEmpty) return f;
      }
      dump('missing $f');
      throw TestFailure('not found: $f');
    }

    Future<void> tap(Finder f, {int pause = 900}) async {
      await wait(f);
      final hit = f.first;
      await t.ensureVisible(hit);
      await hold(250);
      final c = t.getCenter(hit);
      print('NKTAP|${c.dx.toStringAsFixed(1)}|${c.dy.toStringAsFixed(1)}|${ms()}');
      await hold(350); // the tap mark shows a moment before the press
      await t.tapAt(c);
      await hold(pause);
    }

    Future<void> type(Finder field, String text) async {
      t.testTextInput.register(); // letters appear one by one (the phone keyboard would replace them)
      await tap(field, pause: 300);
      for (var i = 1; i <= text.length; i++) {
        await t.enterText(field.first, text.substring(0, i));
        await t.pump(const Duration(milliseconds: 55));
        await hold(55);
      }
      await hold(500);
    }

    Future<void> scroll(double dy) async {
      final s = find.byType(Scrollable);
      if (s.evaluate().isEmpty) return;
      await t.timedDrag(s.first, Offset(0, dy), const Duration(milliseconds: 900 * slow));
      await hold(600);
    }

    timeDilation = slow.toDouble();
    print('NKSLOW|$slow');
    app.main();
    await hold(1500);
    final v = t.view;
    print('NKDPR|${v.devicePixelRatio}|${v.physicalSize.width}|${v.physicalSize.height}');

    // 1. Log in
    await wait(find.text('Continue with Google'), secs: 40);
    step('login');
    await hold(2500);
    await tap(find.text('Continue with Google'), pause: 1500);

    // 2. Shops near home
    await wait(find.text('Gupta General Store'), secs: 40);
    step('home');
    await hold(3500);
    await scroll(-260);
    await scroll(260);

    // 3. Open a shop
    step('shop');
    await tap(find.text('Gupta General Store'), pause: 1800);
    await scroll(-300);
    await hold(800);

    // 4. Add items
    step('add');
    await tap(find.text('ADD').at(0), pause: 1200);
    await tap(find.text('ADD').at(0), pause: 1200);
    await tap(find.text('ADD').at(0), pause: 1500);

    // 5. Cart
    step('cart');
    await tap(find.text('View cart'), pause: 2500);
    await scroll(-250);
    await hold(1500);

    // 6. Place the order
    step('place');
    await tap(find.textContaining('Place order'), pause: 1500);
    if (find.textContaining('Agree & place order').evaluate().isNotEmpty) {
      await hold(2500); // the rules sheet, shown before the first order
      await tap(find.textContaining('Agree & place order'), pause: 1500);
    }
    await wait(find.textContaining('Waiting for the store'), secs: 30);
    await hold(2500);

    // 7. The shop accepts (shop's phone, through the demo server)
    final list = await callApi('GET', '/v1/partner/orders?tab=new', shopToken);
    final orderId = '${(list['orders'] as List).first['id']}';
    await callApi('POST', '/v1/partner/orders/$orderId/accept', shopToken, {});
    step('accepted');
    await hold(4000);

    // 8. Packed and on the way: the delivery person's scooter moves on the map
    await callApi('POST', '/v1/partner/orders/$orderId/send', shopToken, {'na': []});
    step('out');
    await hold(6000); // the map loads its streets
    const shop = (28.590356, 77.089169), home = (28.5895, 77.0884);
    for (var i = 0; i <= 12; i++) {
      final f = i / 12;
      await callApi('POST', '/v1/partner/rider', shopToken,
          {'lat': shop.$1 + (home.$1 - shop.$1) * f, 'lng': shop.$2 + (home.$2 - shop.$2) * f});
      await hold(2200);
    }
    await scroll(-300);
    step('code');
    await hold(3500);

    // 9. Delivered with the code
    final mine = await callApi('GET', '/v1/me/orders', kDemoToken);
    final otp = '${((mine['orders'] as List).firstWhere((o) => '${o['id']}' == orderId) as Map)['otp']}';
    await callApi('POST', '/v1/partner/orders/$orderId/deliver', shopToken, {'otp': otp, 'pay': 'cash'});
    step('delivered');
    await hold(4000);

    // 10. Live thelas
    if (find.text('Not now').evaluate().isNotEmpty) await tap(find.text('Not now'), pause: 800);
    for (var i = 0; i < 5 && find.textContaining('Moving sellers').evaluate().isEmpty; i++) {
      final back = find.byType(BackButton).evaluate().isNotEmpty ? find.byType(BackButton) : find.byIcon(Icons.arrow_back);
      if (back.evaluate().isNotEmpty) {
        await tap(back, pause: 900);
      } else {
        await t.pageBack();
        await hold(900);
      }
    }
    step('thelas');
    await tap(find.textContaining('Moving sellers'), pause: 5000);

    // 11. A thela's page and today's prices
    step('thela');
    await tap(find.text('Ramesh Sabzi Thela'), pause: 6000); // the map shows where the thela stands
    await scroll(-350);
    await hold(1200);

    // 12. Call it to your street
    step('call');
    await tap(find.text('Call to my street'), pause: 1500);
    await tap(find.text('Call to my street').last, pause: 2500);
    final calls = await callApi('GET', '/v1/partner/calls', thelaToken);
    final ids = <String>[];
    for (final g in (calls['groups'] as List? ?? [])) {
      ids.addAll(((g as Map)['ids'] as List? ?? []).map((x) => '$x'));
    }
    if (ids.isEmpty) print('NKAPI|calls body|${jsonEncode(calls)}');
    await callApi('POST', '/v1/partner/calls/answer', thelaToken, {'ids': ids, 'coming': true});
    step('coming');
    await wait(find.textContaining('coming out'), secs: 30);
    await hold(2500);
    await tap(find.textContaining('coming out'), pause: 2500);

    // 13. Chat with the thela
    step('chat');
    await tap(find.textContaining('Chat with'), pause: 1500);
    await type(find.byType(TextField), 'Bhaiya, 1 kg tamatar aur aadha kg bhindi le aana');
    final send = find.byIcon(Icons.send);
    await tap(send, pause: 1500);
    final chats = await callApi('GET', '/v1/partner/chats', thelaToken);
    final chatId = '${((chats['chats'] as List).first as Map)['id']}';
    await callApi('POST', '/v1/partner/chats/$chatId', thelaToken, {'text': 'Haan ji, 5 minute mein aa raha hoon'});
    step('reply');
    await hold(5000);
    step('end');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
