import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api.dart';

/// While this phone has a shop order out for door delivery, share its position so the customer
/// sees the Nukad Kart scooter on the map. Stops when there is nothing to deliver.
class RiderLocation {
  RiderLocation._();
  static final RiderLocation instance = RiderLocation._();
  StreamSubscription<Position>? _sub;
  bool _starting = false;

  /// [outDoorOrders]: how many door orders are out for me (null = unknown, change nothing).
  Future<void> sync({int? outDoorOrders}) async {
    if (outDoorOrders == null) return;
    if (outDoorOrders > 0) {
      await _start();
    } else {
      await stop();
    }
  }

  Future<void> _start() async {
    if (_sub != null || _starting) return;
    _starting = true;
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p != LocationPermission.whileInUse && p != LocationPermission.always) return;
      _sub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Delivering an order',
            notificationText: 'The customer sees you on the map until the order is delivered.',
            notificationIcon: AndroidResource(name: 'launcher_icon', defType: 'mipmap'),
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      ).listen((pos) {
        _send(pos);
      }, onError: (_) {});
      // First position at once (the stream waits for 25 m of movement).
      Geolocator.getCurrentPosition().then(_send).catchError((_) {});
    } finally {
      _starting = false;
    }
  }

  void _send(Position pos) {
    api.call('POST', '/v1/partner/rider', {'lat': pos.latitude, 'lng': pos.longitude}).catchError((_) => <String, dynamic>{});
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
