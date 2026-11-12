import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../data/demo_data.dart';

/// Live status of a moving seller (thela) as the customer sees it.
///  standing    — location came in the last 2 min and the thela hasn't moved for 2 min
///  moving      — location came in the last 2 min and it moved recently
///  wasHere     — last location 2–10 min ago ("Was here 5 min ago")
///  notAvailable — no location for 10 min, switched off, or outside 500 m (the server stops sending it)
enum ThelaStatus { standing, moving, wasHere, notAvailable }

class ThelaLive {
  double d; // metres from the customer's address
  double angle; // direction from the customer (radians, screen: 0 = east, clockwise), for the map
  double prev;
  int seenAgo; // seconds since the thela's phone last sent its location
  DateTime lastSeen = DateTime.now();
  ThelaStatus status = ThelaStatus.notAvailable;
  final List<double> trail = []; // recent distances, newest last
  ThelaLive(this.d, this.angle) : prev = d, seenAgo = 0;
}

/// Positions come from the server (the thela's phone sends them while it is LIVE).
/// The customer app asks again every 20 s; see services/live_data.dart.
class ThelaTracker extends ChangeNotifier {
  ThelaTracker._();
  static final ThelaTracker instance = ThelaTracker._();

  static const double radius = 500;
  static const int freshSec = 120; // newer than this = LIVE

  final Map<String, ThelaLive> live = {};
  final Set<String> _everSeen = {};
  bool _first = true;

  /// Called when a seller who had gone comes back within 500 m.
  void Function(String thelaId)? onBackInArea;

  ThelaLive of(String id) => live[id] ?? ThelaLive(9999, 0);

  void update(double lat, double lng, List<Thela> thelas) {
    final now = DateTime.now();
    final ids = <String>{};
    for (final th in thelas) {
      ids.add(th.id);
      final d = th.distanceM.toDouble();
      final angle = _bearing(lat, lng, th.lat, th.lng) - math.pi / 2;
      final t = live[th.id];
      final wasGone = t == null || t.status == ThelaStatus.notAvailable;
      final lv = t ?? ThelaLive(d, angle);
      lv.prev = lv.d;
      lv.d = d;
      lv.angle = angle;
      lv.seenAgo = th.lastSeenSec;
      lv.lastSeen = now.subtract(Duration(seconds: th.lastSeenSec));
      if (lv.trail.isEmpty || (lv.trail.last - d).abs() > 5) lv.trail.add(d);
      if (lv.trail.length > 6) lv.trail.removeAt(0);
      lv.status = th.lastSeenSec > freshSec
          ? ThelaStatus.wasHere
          : (th.moving ? ThelaStatus.moving : ThelaStatus.standing);
      live[th.id] = lv;
      if (wasGone && !_first && _everSeen.contains(th.id)) onBackInArea?.call(th.id);
      _everSeen.add(th.id);
    }
    for (final e in live.entries) {
      if (!ids.contains(e.key)) e.value.status = ThelaStatus.notAvailable;
    }
    _first = false;
    notifyListeners();
  }

  /// Address changed: forget positions so nobody is announced as "back".
  void reset() {
    live.clear();
    _everSeen.clear();
    _first = true;
    notifyListeners();
  }

  static double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180, dl = (lng2 - lng1) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return math.atan2(y, x); // 0 = north, clockwise
  }
}
