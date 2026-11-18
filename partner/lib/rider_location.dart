import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api.dart';

/// While this phone has a shop order out for door delivery, share its position so the customer
/// sees the Nukkad Kart scooter on the map. Stops when there is nothing to deliver.
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
          accuracy: LocationAccuracy.best,
          // Every ~3 s, also standing still: the customer's scooter keeps gliding, and the customer is told only
          // when spots really stop coming (GPS or internet off on this phone).
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Delivering an order',
            notificationText: 'The customer sees you on the map until the order is delivered.',
            notificationIcon: AndroidResource(name: 'ic_stat_nukad', defType: 'drawable'),
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      ).listen((pos) {
        _send(pos);
      }, onError: (_) {});
      // First position at once, from GPS (not the rough network position that can be 500 m off).
      Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)))
          .then(_send)
          .catchError((_) {});
    } finally {
      _starting = false;
    }
  }

  void _send(Position pos) {
    // A rough fix (wifi / tower, 100 m+ off) would put the scooter in the wrong street: wait for GPS.
    if (pos.accuracy > 60) return;
    api.call('POST', '/v1/partner/rider', {'lat': pos.latitude, 'lng': pos.longitude}).catchError((_) => <String, dynamic>{});
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
