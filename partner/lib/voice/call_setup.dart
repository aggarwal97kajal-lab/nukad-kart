// Phone settings so in-app calls ring while the app is closed (same file in the customer and the Partner app).
// Xiaomi / Redmi / Poco, Oppo, Realme, Vivo, OnePlus… stop a closed app from getting its ring unless "Autostart"
// is on and battery saving is off for it. Asked once per phone, after sign-in; can be opened again from settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _w(String k, String lang) {
  const hi = {
    'title': 'ऐप बंद हो तब भी कॉल आए',
    'body': 'आपका फ़ोन बंद ऐप की कॉल रोक देता है। ये 2 सेटिंग एक बार ऑन करें:',
    'auto': '1. Autostart ऑन करें',
    'battery': '2. बैटरी: No restrictions',
    'done': 'हो गया',
    'later': 'बाद में',
  };
  const hg = {
    'title': 'App band ho tab bhi call aaye',
    'body': 'Aapka phone band app ki call rok deta hai. Ye 2 setting ek baar on karo:',
    'auto': '1. Autostart on karo',
    'battery': '2. Battery: No restrictions',
    'done': 'Ho gaya',
    'later': 'Baad mein',
  };
  const en = {
    'title': 'Get calls when the app is closed',
    'body': 'Your phone blocks calls for closed apps. Turn on these 2 settings once:',
    'auto': '1. Turn on Autostart',
    'battery': '2. Battery: No restrictions',
    'done': 'Done',
    'later': 'Later',
  };
  final m = lang == 'hi' ? hi : (lang == 'hg' ? hg : en);
  return m[k] ?? en[k] ?? k;
}

class CallSetup {
  final MethodChannel _ch;
  CallSetup(String channel) : _ch = MethodChannel(channel);

  Future<String> brand() async {
    try {
      return await _ch.invokeMethod<String>('brand') ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> batteryFree() async {
    try {
      return await _ch.invokeMethod<bool>('batteryFree') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> askBattery() async {
    try {
      await _ch.invokeMethod('askBattery');
    } catch (_) {}
  }

  Future<void> autostart() async {
    try {
      await _ch.invokeMethod('autostart');
    } catch (_) {}
  }

  /// Phones that stop closed apps unless "Autostart" is on.
  static bool needsAutostart(String brand) =>
      ['xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'vivo', 'iqoo', 'huawei', 'honor', 'oneplus', 'asus', 'tecno', 'infinix', 'itel']
          .any(brand.contains);

  /// Once per phone: if this phone needs it, show the two buttons. [force]: show again (from settings).
  Future<void> askOnce(BuildContext context, String lang, {bool force = false}) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!force && p.getBool('call_setup_asked') == true) return;
      final auto = needsAutostart(await brand());
      final battery = !await batteryFree();
      if (!force && !auto && !battery) return;
      await p.setBool('call_setup_asked', true);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_w('title', lang)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_w('body', lang)),
            const SizedBox(height: 14),
            if (auto || force)
              OutlinedButton.icon(onPressed: autostart, icon: const Icon(Icons.play_circle_outline), label: Text(_w('auto', lang))),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: askBattery, icon: const Icon(Icons.battery_charging_full), label: Text(_w('battery', lang))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_w('later', lang))),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(_w('done', lang))),
          ],
        ),
      );
    } catch (_) {}
  }
}
