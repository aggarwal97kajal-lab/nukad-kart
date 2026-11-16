import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../l10n.dart';
import '../services/ola_maps.dart';
import 'ui.dart';

/// Real map for a shop delivery: named pins for the customer's home and the shop, the road route between them
/// (Ola directions, one call per order), and the Nukad Kart scooter (the delivery person's phone) driving along
/// that route like in Swiggy / Zomato / Blinkit: it moves smoothly along the road (never jumps across buildings),
/// faces the way it is going (the brand scooter, mirrored when it drives left), and the route behind it
/// disappears. The rider's phone sends its spot every ~3 s; it arrives here at once over the order's live socket
/// (or by asking every 3 s when the socket is down), and each move is drawn over the time until the next one.
/// Light on the phone, like those apps: the map gets a new scooter spot 4 times a second (not every frame), the
/// route line once a second, and nothing at all while another screen (a call) is on top.
/// The camera fits home + shop + scooter; "Recentre" brings it back after the customer pans.
class RiderMap extends StatefulWidget {
  final double homeLat, homeLng;
  final double? riderLat, riderLng;
  final String storeName;
  final double? shopLat, shopLng;

  /// Order id: the road route is fetched once per order; live scooter spots come for this order.
  final String routeKey;

  /// API address and the customer's session (for the live socket and /v1/me/orders/:id/rider).
  final String base;
  final String Function()? token;
  const RiderMap(
      {super.key,
      required this.homeLat,
      required this.homeLng,
      this.riderLat,
      this.riderLng,
      required this.storeName,
      this.shopLat,
      this.shopLng,
      this.routeKey = '',
      this.base = '',
      this.token});
  @override
  State<RiderMap> createState() => _RiderMapState();
}

class _RiderMapState extends State<RiderMap> with SingleTickerProviderStateMixin {
  late final Future<String> _style = OlaMaps.style(dark: gDark, lang: gLang);
  MapLibreMapController? _c;
  Widget? _map;
  Symbol? _rider;
  Line? _ahead;
  bool _ready = false, _icon = false;
  List<LatLng> _route = [];
  List<double> _cum = []; // metres from the shop to each route point

  // Where the scooter is drawn: metres along the route (on the road), or a free point when it is off the route.
  double? _shownD;
  LatLng? _shownP;
  double _bearing = 0;

  // The move being drawn now: from → to over _animMs.
  double? _fromD, _toD;
  LatLng? _fromP, _toP;
  double _animMs = 3000;
  Ticker? _tk;
  Ticker get _ticker => _tk ??= createTicker(_onTick);
  Duration _lastDraw = Duration.zero, _lastLine = Duration.zero;
  bool _drawing = false;

  // Last spot from the rider's phone (to skip repeats) and when it came (the next move takes that long).
  LatLng? _lastFix;
  DateTime? _lastFixAt;

  // When the rider's phone last sent its spot (also when it didn't move). 40 s without one: say so on the map.
  DateTime? _seenAt;

  // Live spots.
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _poll, _ping, _retry;
  bool _live = false, _gone = false;

  bool get _hasShop => widget.shopLat != null && widget.shopLat != 0;

  @override
  void initState() {
    super.initState();
    if (widget.routeKey.isNotEmpty && widget.base.isNotEmpty && widget.token != null) {
      _connect();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!_live) _fetch();
      });
    }
  }

  @override
  void didUpdateWidget(RiderMap old) {
    super.didUpdateWidget(old);
    if ((old.riderLat != widget.riderLat || old.riderLng != widget.riderLng) && widget.riderLat != null) {
      _fix(LatLng(widget.riderLat!, widget.riderLng!));
    }
  }

  @override
  void dispose() {
    _gone = true;
    _tk?.dispose();
    _poll?.cancel();
    _ping?.cancel();
    _retry?.cancel();
    _wsSub?.cancel();
    try {
      _ws?.sink.close();
    } catch (_) {}
    super.dispose();
  }

  // ----- live spots from the rider's phone -----

  void _seen(DateTime at) {
    if (_seenAt == null || at.isAfter(_seenAt!)) _seenAt = at;
  }

  /// No spot from the rider's phone for 40 s (GPS or internet off there).
  bool get _stale => _seenAt != null && DateTime.now().difference(_seenAt!).inSeconds > 40;

  void _connect() {
    if (_gone) return;
    try {
      final ws = widget.base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      _ws = IOWebSocketChannel.connect(Uri.parse('$ws/v1/orders/${Uri.encodeComponent(widget.routeKey)}/chat/socket'),
          headers: {'authorization': 'Bearer ${widget.token!()}'});
      _wsSub = _ws!.stream.listen((m) {
        _live = true;
        try {
          final d = jsonDecode('$m');
          if (d is Map && d['type'] == 'rider') {
            _seen(DateTime.now());
            _fix(LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()));
          }
        } catch (_) {}
      }, onDone: _lost, onError: (_) => _lost());
      _ws!.ready.then((_) => _live = true).catchError((_) => _lost());
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ws?.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    _live = false;
    _ping?.cancel();
    _wsSub?.cancel();
    if (_gone) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 4), _connect);
  }

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse('${widget.base}/v1/me/orders/${Uri.encodeComponent(widget.routeKey)}/rider'),
          headers: {'authorization': 'Bearer ${widget.token!()}'}).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final rd = (jsonDecode(r.body) as Map)['rider'];
      if (rd is Map) {
        _seen(DateTime.now().subtract(Duration(seconds: ((rd['ago'] as num?) ?? 0).toInt())));
        _fix(LatLng((rd['lat'] as num).toDouble(), (rd['lng'] as num).toDouble()));
      }
    } catch (_) {}
  }

  /// A round pin with an emoji and a name tag under it ("🏠 Ghar", "🏪 Dukaan"), drawn on the phone so it
  /// does not depend on the map's fonts.
  static Future<Uint8List> _pin(String emoji, String label, Color bg) async {
    const w = 200.0, h = 150.0, k = 3.0; // drawn 3× (map images are in screen pixels)
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec)..scale(k);
    final circle = Offset(w / 2, 46);
    cv.drawCircle(circle.translate(0, 2), 40, Paint()..color = const Color(0x33000000));
    cv.drawCircle(circle, 40, Paint()..color = Colors.white);
    cv.drawCircle(circle, 34, Paint()..color = bg);
    final e = TextPainter(text: TextSpan(text: emoji, style: const TextStyle(fontSize: 34)), textDirection: TextDirection.ltr)..layout();
    e.paint(cv, circle - Offset(e.width / 2, e.height / 2));
    final t = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: w - 16);
    final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, 116), width: t.width + 24, height: t.height + 10), const Radius.circular(14));
    cv.drawRRect(tag, Paint()..color = const Color(0xFF21331B));
    t.paint(cv, Offset(w / 2 - t.width / 2, 116 - t.height / 2));
    final img = await rec.endRecording().toImage((w * k).toInt(), (h * k).toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }

  Future<void> _onStyle() async {
    final c = _c;
    if (c == null) return;
    final home = LatLng(widget.homeLat, widget.homeLng);
    // Pins and the scooter can sit close together: show all of them (by default the map hides overlapping ones).
    try {
      await c.setSymbolIconAllowOverlap(true);
      await c.setSymbolIconIgnorePlacement(true);
    } catch (_) {}
    try {
      await c.addImage('nk-home', await _pin('🏠', t('Your home'), const Color(0xFF2E7D32)));
      if (_hasShop) await c.addImage('nk-shop', await _pin('🏪', t('The shop'), const Color(0xFF185FA5)));
      final b = (await rootBundle.load('assets/images/markers/bike.png')).buffer.asUint8List();
      await c.addImage('nk-bike', b);
      await c.addImage('nk-bike-l', await _mirror(b));
      _icon = true;
    } catch (_) {}
    // Road route shop → home (one Ola call per order, cached).
    if (_hasShop) {
      final pts = await OlaMaps.route(widget.routeKey.isEmpty ? '${widget.shopLat},${widget.shopLng}-${widget.homeLat},${widget.homeLng}' : widget.routeKey,
          widget.shopLat!, widget.shopLng!, widget.homeLat, widget.homeLng);
      _route = pts.map((p) => LatLng(p.$1, p.$2)).toList();
      if (_route.isEmpty) _route = [LatLng(widget.shopLat!, widget.shopLng!), home];
      _cum = [0];
      for (var i = 1; i < _route.length; i++) {
        _cum.add(_cum.last + _dist(_route[i - 1].latitude, _route[i - 1].longitude, _route[i].latitude, _route[i].longitude));
      }
      // Faint full route, and the part still ahead of the scooter in bold.
      await c.addLine(LineOptions(geometry: _route, lineColor: '#9AA59A', lineWidth: 4, lineOpacity: 0.6));
      _ahead = await c.addLine(LineOptions(geometry: _route, lineColor: '#21331B', lineWidth: 5, lineOpacity: 0.95));
    }
    if (_icon) {
      if (_hasShop) await c.addSymbol(SymbolOptions(geometry: LatLng(widget.shopLat!, widget.shopLng!), iconImage: 'nk-shop', iconSize: 0.5, iconAnchor: 'center'));
      await c.addSymbol(SymbolOptions(geometry: home, iconImage: 'nk-home', iconSize: 0.5, iconAnchor: 'center'));
    } else {
      await c.addCircle(CircleOptions(geometry: home, circleRadius: 9, circleColor: '#2E7D32', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
    }
    _ready = true;
    await _fit();
    // Start at the rider's last spot, or at the shop until the rider's phone sends one.
    final first = widget.riderLat != null ? LatLng(widget.riderLat!, widget.riderLng!) : (_lastFix ?? (_hasShop ? LatLng(widget.shopLat!, widget.shopLng!) : null));
    if (first != null) await _place(first);
    if (widget.routeKey.isNotEmpty && widget.base.isNotEmpty && widget.token != null) _fetch();
  }

  /// The brand scooter faces right; this is it facing left (for driving west).
  static Future<Uint8List> _mirror(Uint8List png) async {
    final img = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec)
      ..translate(img.width.toDouble(), 0)
      ..scale(-1, 1);
    cv.drawImage(img, Offset.zero, Paint());
    final out = await rec.endRecording().toImage(img.width, img.height);
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Camera shows home, shop and scooter together.
  Future<void> _fit() async {
    final c = _c;
    if (c == null) return;
    final pts = <LatLng>[
      LatLng(widget.homeLat, widget.homeLng),
      if (_hasShop) LatLng(widget.shopLat!, widget.shopLng!),
      if (_shownP != null) _shownP! else if (widget.riderLat != null) LatLng(widget.riderLat!, widget.riderLng!),
    ];
    const pad = 0.0008;
    final sw = LatLng(pts.map((p) => p.latitude).reduce(math.min) - pad, pts.map((p) => p.longitude).reduce(math.min) - pad);
    final ne = LatLng(pts.map((p) => p.latitude).reduce(math.max) + pad, pts.map((p) => p.longitude).reduce(math.max) + pad);
    await c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), left: 50, top: 60, right: 50, bottom: 70));
  }

  /// Nearest point on the route and the index of the segment it is on. The scooter is snapped to the road
  /// when the phone is within 60 m of it (GPS drifts into buildings); farther off, the real position is shown.
  (LatLng, int)? _snap(LatLng p) {
    if (_route.length < 2) return null;
    var best = double.infinity;
    LatLng? at;
    var seg = 0;
    final k = math.cos(p.latitude * math.pi / 180);
    for (var i = 0; i < _route.length - 1; i++) {
      final a = _route[i], b = _route[i + 1];
      final ax = a.longitude * k, ay = a.latitude, bx = b.longitude * k, by = b.latitude, px = p.longitude * k, py = p.latitude;
      final dx = bx - ax, dy = by - ay;
      final l2 = dx * dx + dy * dy;
      final t = l2 == 0 ? 0.0 : (((px - ax) * dx + (py - ay) * dy) / l2).clamp(0.0, 1.0);
      final q = LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
      final d = _dist(p.latitude, p.longitude, q.latitude, q.longitude);
      if (d < best) {
        best = d;
        at = q;
        seg = i;
      }
    }
    return best <= 60 && at != null ? (at, seg) : null;
  }

  /// Metres along the route of point [p] on segment [seg].
  double _along(LatLng p, int seg) => _cum[seg] + _dist(_route[seg].latitude, _route[seg].longitude, p.latitude, p.longitude);

  /// The point [d] metres along the route, its segment, and the road's direction there (degrees from north).
  (LatLng, int, double) _pointAt(double d) {
    final x = d.clamp(0.0, _cum.last);
    var i = 0;
    while (i < _cum.length - 2 && _cum[i + 1] < x) {
      i++;
    }
    final a = _route[i], b = _route[i + 1];
    final len = _cum[i + 1] - _cum[i];
    final f = len <= 0 ? 0.0 : (x - _cum[i]) / len;
    return (
      LatLng(a.latitude + (b.latitude - a.latitude) * f, a.longitude + (b.longitude - a.longitude) * f),
      i,
      _heading(a, b),
    );
  }

  static double _heading(LatLng a, LatLng b) {
    final p1 = a.latitude * math.pi / 180, p2 = b.latitude * math.pi / 180, dl = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Scooter picture for a direction: facing right while it drives east-ish, mirrored for west-ish; straight
  /// north / south keeps the last one (so it doesn't flip back and forth on a straight road).
  String _bike = 'nk-bike';
  String _bikeFor(double bearing) {
    if (!_icon) return 'nk-bike';
    if (bearing > 20 && bearing < 160) _bike = 'nk-bike';
    if (bearing > 200 && bearing < 340) _bike = 'nk-bike-l';
    return _bike;
  }

  /// First spot: put the scooter there (no animation).
  Future<void> _place(LatLng raw) async {
    final c = _c;
    if (c == null || _rider != null) return;
    final snap = _snap(raw);
    final at = snap?.$1 ?? raw;
    if (snap != null && _cum.isNotEmpty) {
      _shownD = _along(snap.$1, snap.$2);
      _bearing = _pointAt(_shownD!).$3;
    }
    _shownP = at;
    _lastFix ??= raw;
    _lastFixAt ??= DateTime.now();
    _rider = await c.addSymbol(_icon
        ? SymbolOptions(geometry: at, iconImage: _bikeFor(_bearing), iconSize: 0.42, iconAnchor: 'bottom')
        : SymbolOptions(geometry: at, textField: '🛵', textSize: 24));
    if (_ahead != null && snap != null) await c.updateLine(_ahead!, LineOptions(geometry: [at, ..._route.sublist(snap.$2 + 1)]));
    if (mounted) setState(() {});
    await _fit();
  }

  /// A new spot from the rider's phone: drive there along the road over the time the last spot took to come.
  void _fix(LatLng raw) {
    if (_lastFix != null && _dist(_lastFix!.latitude, _lastFix!.longitude, raw.latitude, raw.longitude) < 1) return;
    final now = DateTime.now();
    final gap = _lastFixAt == null ? 3000 : now.difference(_lastFixAt!).inMilliseconds.clamp(1500, 6000);
    _lastFix = raw;
    _lastFixAt = now;
    if (!_ready || _c == null) return;
    if (_rider == null) {
      _place(raw);
      return;
    }
    final snap = _snap(raw);
    if (snap != null && _cum.isNotEmpty && _shownD != null) {
      final d = _along(snap.$1, snap.$2);
      // GPS wobble a few metres backwards: hold still rather than reverse.
      if (d < _shownD! && _shownD! - d < 30) return;
      _fromD = _shownD;
      _toD = d;
      _fromP = _toP = null;
    } else {
      _fromP = _shownP;
      _toP = snap?.$1 ?? raw;
      _fromD = _toD = null;
      if (snap != null && _cum.isNotEmpty) _shownD = _along(snap.$1, snap.$2);
    }
    _animMs = gap.toDouble();
    _lastDraw = _lastLine = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void _onTick(Duration el) {
    final c = _c;
    if (c == null || _rider == null) return;
    final f = (el.inMilliseconds / _animMs).clamp(0.0, 1.0);
    final done = f >= 1.0;
    // 4 map updates a second (like Blinkit / Zepto): smooth to the eye, and the phone stays free for touches.
    if (!done && (el - _lastDraw).inMilliseconds < 250) return;
    if (_drawing && !done) return;
    // Another screen (a call, the chat) is on top: don't touch the map at all.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      if (done) _tk?.stop();
      return;
    }
    _lastDraw = el;
    LatLng p;
    double want = _bearing;
    int? seg;
    if (_fromD != null && _toD != null) {
      final d = _fromD! + (_toD! - _fromD!) * f;
      final at = _pointAt(d);
      p = at.$1;
      seg = at.$2;
      want = at.$3;
      _shownD = d;
    } else if (_fromP != null && _toP != null) {
      p = LatLng(_fromP!.latitude + (_toP!.latitude - _fromP!.latitude) * f, _fromP!.longitude + (_toP!.longitude - _fromP!.longitude) * f);
      if (_dist(_fromP!.latitude, _fromP!.longitude, _toP!.latitude, _toP!.longitude) > 3) want = _heading(_fromP!, _toP!);
    } else {
      _ticker.stop();
      return;
    }
    _shownP = p;
    _bearing = want;
    _drawing = true;
    c.updateSymbol(_rider!, SymbolOptions(geometry: p, iconImage: _bikeFor(_bearing))).whenComplete(() => _drawing = false);
    // The road still ahead: redrawn once a second.
    if (_ahead != null && seg != null && (done || (el - _lastLine).inMilliseconds >= 1000)) {
      _lastLine = el;
      c.updateLine(_ahead!, LineOptions(geometry: [p, ..._route.sublist(seg + 1)]));
    }
    if (done) {
      _ticker.stop();
      if (mounted) setState(() {}); // distance / minutes left
    }
  }

  @override
  Widget build(BuildContext context) {
    // Distance still to go: along the road when the scooter is on it, else straight to the door.
    final at = _shownP ?? _lastFix ?? (widget.riderLat == null ? null : LatLng(widget.riderLat!, widget.riderLng!));
    final double? d = _shownD != null && _cum.isNotEmpty
        ? math.max(0.0, _cum.last - _shownD!)
        : (at == null ? null : _dist(widget.homeLat, widget.homeLng, at.latitude, at.longitude));
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 300,
        child: FutureBuilder<String>(
          future: _style,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Container(
                  color: kSurf,
                  alignment: Alignment.center,
                  child: snap.hasError ? Text('On the way from ${widget.storeName}', style: head(15)) : CircularProgressIndicator());
            }
            return Stack(children: [
              // Built once: the order screen redraws every second, and rebuilding the map view each time costs the phone.
              _map ??= MapLibreMap(
                styleString: snap.data!,
                initialCameraPosition: CameraPosition(target: LatLng(widget.homeLat, widget.homeLng), zoom: 15.2),
                minMaxZoomPreference: MinMaxZoomPreference(12, 18.5),
                onMapCreated: (c) => _c = c,
                onStyleLoadedCallback: _onStyle,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: kCard,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: t('Recentre'),
                    icon: Icon(Icons.center_focus_strong, color: kInk, size: 22),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _fit();
                    },
                  ),
                ),
              ),
              if (_stale)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 12,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(20)),
                      child: Text(tr('Rider’s location hasn’t updated for {0} sec', [DateTime.now().difference(_seenAt!).inSeconds]),
                          style: body(11, color: Color(0xFF633806), weight: FontWeight.w800)),
                    ),
                  ),
                ),
              // Small pill at the bottom (minutes · metres), like the delivery apps.
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Color(0xFF21331B), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        d == null
                            ? tr('On the way from {0}', [widget.storeName])
                            : tr('{0} min · {1} m', [(d / 250).ceil().clamp(1, 30), d.round()]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(11, color: kBrand, weight: FontWeight.w800)),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  static double _dist(double a1, double o1, double a2, double o2) {
    const r = 6371000.0;
    final p1 = a1 * math.pi / 180, p2 = a2 * math.pi / 180, dp = (a2 - a1) * math.pi / 180, dl = (o2 - o1) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
