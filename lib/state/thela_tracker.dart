import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Live status of a moving seller (thela) as the customer sees it.
enum ThelaStatus { hereNow, movingAway, notAvailable }

class ThelaLive {
  double d; // metres from the customer's address
  double angle; // direction from the customer (radians), for the map
  double prev;
  DateTime? outsideSince;
  DateTime lastSeen = DateTime.now();
  ThelaStatus status = ThelaStatus.hereNow;
  final List<double> trail = []; // recent distances, newest last
  ThelaLive(this.d, this.angle) : prev = d;
}

/// Demo: simulates the seller's phone GPS. In the real app the Partner app
/// sends the thela's position every 10 s while the seller has turned on "Live",
/// and the server shares it only with customers within 500 m.
/// The seller's home / saved address is never sent to customers.
class ThelaTracker extends ChangeNotifier {
  ThelaTracker._();
  static final ThelaTracker instance = ThelaTracker._();

  static const double radius = 500; // customer's area
  static const double edge = 400; // past this and moving out = "Moving away"
  /// Must stay outside 500 m this long before "Not available" (GPS can jump ±30 m).
  /// Real app: 30 s. Demo: 10 s so you can see it change quickly.
  static const Duration outsideGrace = Duration(seconds: 10);

  final Map<String, ThelaLive> live = {
    't1': ThelaLive(220, -0.6),
    't2': ThelaLive(380, 0.35),
    't3': ThelaLive(450, 2.6),
  };

  /// Called when a seller who had left comes back inside 500 m.
  void Function(String thelaId)? onBackInArea;

  Timer? _timer;
  int _tick = 0;
  int _listeners = 0;

  ThelaLive of(String id) => live[id] ?? ThelaLive(9999, 0);

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _timer ??= Timer.periodic(Duration(seconds: 2), (_) => _step());
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners--;
    if (_listeners <= 0) {
      _listeners = 0;
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Scripted demo routes (one tick = 2 s).
  double _route(String id, int k) {
    switch (id) {
      case 't1': // stays nearby, walking around the colony
        return 230 + 70 * math.sin(k / 6);
      case 't2': // walks out of the area, waits, comes back (2-minute loop)
        final p = k % 60;
        if (p < 25) return 380 + 6.0 * p; // 380 → 530
        if (p < 40) return 530 + 3.0 * (p - 25); // 530 → 575
        return 575 - 10.0 * (p - 40); // 575 → 375
      default: // t3: drifts in and out around the edge
        return 470 + 90 * math.sin((k + 20) / 8);
    }
  }

  void _step() {
    _tick++;
    final now = DateTime.now();
    live.forEach((id, t) {
      t.prev = t.d;
      t.d = _route(id, _tick);
      t.angle += 0.02;
      t.trail.add(t.d);
      if (t.trail.length > 6) t.trail.removeAt(0);
      final before = t.status;
      t.status = statusFor(t, now);
      if (t.status != ThelaStatus.notAvailable) t.lastSeen = now;
      if (before == ThelaStatus.notAvailable && t.status != ThelaStatus.notAvailable) {
        t.trail.clear();
        onBackInArea?.call(id);
      }
    });
    notifyListeners();
  }

  /// The status rule shown to customers.
  static ThelaStatus statusFor(ThelaLive t, DateTime now) {
    if (t.d <= radius) {
      t.outsideSince = null;
      final goingOut = t.d - t.prev > 1;
      return (t.d > edge && goingOut) ? ThelaStatus.movingAway : ThelaStatus.hereNow;
    }
    t.outsideSince ??= now;
    return now.difference(t.outsideSince!) >= outsideGrace ? ThelaStatus.notAvailable : ThelaStatus.movingAway;
  }
}
