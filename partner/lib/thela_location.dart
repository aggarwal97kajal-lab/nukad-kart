import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'api.dart';
import 'session.dart';

/// A LIVE thela's location, sent to the server so nearby customers see it.
///
/// Battery plan:
///  * Balanced accuracy (phone towers + Wi-Fi, GPS only when needed) while moving.
///  * Sends only after ~75 m of movement, not on a timer.
///  * When standing, one precise GPS fix every 4 minutes as a "still here".
///  * Runs as an ongoing notification ("Nukad Partner is sharing your location"), so Android
///    keeps it alive with the screen off — no "Allow all the time" location needed.
/// No location for 10 minutes → the server hides the thela and sends a push.
class ThelaLocation {
  ThelaLocation._();
  static final ThelaLocation instance = ThelaLocation._();
  static const _ch = MethodChannel('nukadpartner/device');

  StreamSubscription<Position>? _sub;
  Timer? _beat;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool get running => _sub != null;

  // ----- phone setup checks (shown before going LIVE) -----
  static Future<bool> locationAllowed() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  static Future<bool> locationOn() => Geolocator.isLocationServiceEnabled();

  static Future<bool> batteryFree() async {
    try {
      return await _ch.invokeMethod<bool>('batteryFree') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> askBattery() async {
    try {
      await _ch.invokeMethod('askBattery');
    } catch (_) {}
  }

  static Future<void> openAutostart() async {
    try {
      await _ch.invokeMethod('autostart');
    } catch (_) {
      await Geolocator.openAppSettings();
    }
  }

  static Future<String> brand() async {
    try {
      return await _ch.invokeMethod<String>('brand') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Phones that stop background apps unless "Autostart" is on.
  static bool needsAutostart(String brand) =>
      ['xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'vivo', 'iqoo', 'huawei', 'honor', 'oneplus', 'asus', 'tecno', 'infinix', 'itel']
          .any(brand.contains);

  static Future<bool> ready() async => await locationAllowed() && await locationOn() && await batteryFree();

  // ----- sending -----
  Future<void> start() async {
    if (running) return;
    if (!await locationAllowed() || !await locationOn()) return;
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 75,
      intervalDuration: const Duration(seconds: 30),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'You are LIVE on Nukad Kart',
        notificationText: 'Sharing your thela’s location with customers nearby. Turn LIVE off to stop.',
        notificationIcon: AndroidResource(name: 'launcher_icon', defType: 'mipmap'),
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_send, onError: (_) {});
    _beat = Timer.periodic(const Duration(minutes: 1), (_) => _heartbeat());
    _precise();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _beat?.cancel();
    _beat = null;
  }

  /// Match the LIVE switch (also after the app restarts).
  Future<void> sync() async {
    final s = session.store;
    final on = s != null && s['kind'] == 'thela' && s['live'] == true;
    if (on) {
      await start();
    } else {
      await stop();
    }
  }

  void _heartbeat() {
    if (DateTime.now().difference(_lastSent) >= const Duration(minutes: 4)) _precise();
  }

  Future<void> _precise() async {
    try {
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
      await _send(p);
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) await _send(p);
      } catch (_) {}
    }
  }

  Future<void> _send(Position p) async {
    if (p.accuracy > 300) return; // too rough to show on a map
    _lastSent = DateTime.now();
    try {
      final r = await api.call('POST', '/v1/partner/location', {
        'lat': p.latitude,
        'lng': p.longitude,
        if (p.speed > 0.5 && p.heading >= 0) 'heading': p.heading,
      });
      if (r['live'] == false) {
        await stop(); // switched off from another phone, or by the server
        session.refresh().catchError((_) {});
      }
    } catch (_) {}
  }
}
