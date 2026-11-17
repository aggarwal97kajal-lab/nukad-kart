// Helpers for the how-to video tours (see tool/demo). Each step and tap is printed so the video can be captioned.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nukad_partner/api.dart';

const customerToken = String.fromEnvironment('CUSTOMER_TOKEN');

/// Slow motion: animations run this many times slower and the video is sped up as much (smooth on the slow emulator).
const slow = 6;

int ms() => DateTime.now().millisecondsSinceEpoch;
void step(String id) => print('NKSTEP|$id|${ms()}');

Future<Map<String, dynamic>> callApi(String method, String path, String token, [Map<String, dynamic>? body]) async {
  final req = http.Request(method, Uri.parse('$apiBase$path'))
    ..headers['authorization'] = 'Bearer $token'
    ..headers['content-type'] = 'application/json';
  if (body != null) req.body = jsonEncode(body);
  final res = await http.Response.fromStream(await req.send());
  print('NKAPI|$method $path|${res.statusCode}|${res.statusCode >= 400 ? res.body : ''}');
  return res.body.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(res.body) as Map);
}

class Tour {
  final WidgetTester t;
  Tour(this.t);

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

  bool has(Finder f) => f.evaluate().isNotEmpty;

  /// First run: language and theme, then "Who are you?" (shop or thela), then the login screen.
  Future<void> onboard(String kindTitle) async {
    final end = ms() + 40000 * slow;
    while (ms() < end && !has(find.text('Continue with Google')) && !has(find.text('Who are you?')) && !has(find.text('Continue'))) {
      await t.pump(const Duration(milliseconds: 100));
    }
    if (has(find.textContaining('Choose language'))) {
      step('login');
      await hold(1800);
      await tap(find.text('Continue').last, pause: 1200);
    }
    if (has(find.text('Who are you?')) || has(find.text(kindTitle))) {
      step('login');
      await wait(find.text(kindTitle));
      await hold(800);
      await tap(find.text(kindTitle), pause: 1000);
      await tap(find.text('Continue').last, pause: 1500);
    }
    await wait(find.text('Continue with Google'), secs: 40);
    step('login');
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
    await hold(350);
    await t.tapAt(c);
    await hold(pause);
  }

  Future<void> type(Finder field, String text) async {
    t.testTextInput.register();
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

  void start() {
    timeDilation = slow.toDouble();
    print('NKSLOW|$slow');
  }

  void dpr() {
    final v = t.view;
    print('NKDPR|${v.devicePixelRatio}|${v.physicalSize.width}|${v.physicalSize.height}');
  }
}
