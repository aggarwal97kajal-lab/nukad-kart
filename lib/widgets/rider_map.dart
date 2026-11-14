import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../l10n.dart';
import '../services/ola_maps.dart';
import 'ui.dart';

/// Real map for a shop delivery: named pins for the customer's home and the shop, the road route between them
/// (Ola directions, one call per order), and the Nukad Kart scooter (the delivery person's phone) gliding along
/// that route. The camera fits home + shop + scooter; "Recentre" brings it back after the customer pans.
class RiderMap extends StatefulWidget {
  final double homeLat, homeLng;
  final double? riderLat, riderLng;
  final String storeName;
  final double? shopLat, shopLng;

  /// Order id: the road route is fetched once per order.
  final String routeKey;
  const RiderMap(
      {super.key,
      required this.homeLat,
      required this.homeLng,
      this.riderLat,
      this.riderLng,
      required this.storeName,
      this.shopLat,
      this.shopLng,
      this.routeKey = ''});
  @override
  State<RiderMap> createState() => _RiderMapState();
}

class _RiderMapState extends State<RiderMap> {
  late final Future<String> _style = OlaMaps.style(dark: gDark, lang: gLang);
  MapLibreMapController? _c;
  Symbol? _rider;
  Line? _ahead;
  bool _ready = false, _icon = false;
  List<LatLng> _route = [];

  // The scooter is drawn here and slides to each new phone position over ~2.5 s.
  LatLng? _shown;
  Timer? _anim;

  bool get _hasShop => widget.shopLat != null && widget.shopLat != 0;

  @override
  void didUpdateWidget(RiderMap old) {
    super.didUpdateWidget(old);
    if (old.riderLat != widget.riderLat || old.riderLng != widget.riderLng) _move();
  }

  @override
  void dispose() {
    _anim?.cancel();
    super.dispose();
  }

  /// A round pin with an emoji and a name tag under it ("🏠 Ghar", "🏪 Dukaan"), drawn on the phone so it
  /// does not depend on the map's fonts.
  static Future<Uint8List> _pin(String emoji, String label, Color bg) async {
    const w = 200.0, h = 150.0;
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
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
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }

  Future<void> _onStyle() async {
    final c = _c;
    if (c == null) return;
    final home = LatLng(widget.homeLat, widget.homeLng);
    try {
      await c.addImage('nk-home', await _pin('🏠', t('Your home'), const Color(0xFF2E7D32)));
      if (_hasShop) await c.addImage('nk-shop', await _pin('🏪', t('The shop'), const Color(0xFF185FA5)));
      final b = await rootBundle.load('assets/images/markers/bike.png');
      await c.addImage('nk-bike', b.buffer.asUint8List());
      _icon = true;
    } catch (_) {}
    // Road route shop → home (one Ola call per order, cached).
    if (_hasShop) {
      final pts = await OlaMaps.route(widget.routeKey.isEmpty ? '${widget.shopLat},${widget.shopLng}-${widget.homeLat},${widget.homeLng}' : widget.routeKey,
          widget.shopLat!, widget.shopLng!, widget.homeLat, widget.homeLng);
      _route = pts.map((p) => LatLng(p.$1, p.$2)).toList();
      if (_route.isEmpty) _route = [LatLng(widget.shopLat!, widget.shopLng!), home];
      // Faint full route, and the part still ahead of the scooter in bold.
      await c.addLine(LineOptions(geometry: _route, lineColor: '#9AA59A', lineWidth: 4, lineOpacity: 0.6));
      _ahead = await c.addLine(LineOptions(geometry: _route, lineColor: '#21331B', lineWidth: 5, lineOpacity: 0.95));
    }
    if (_icon) {
      if (_hasShop) await c.addSymbol(SymbolOptions(geometry: LatLng(widget.shopLat!, widget.shopLng!), iconImage: 'nk-shop', iconSize: 0.42, iconAnchor: 'center'));
      await c.addSymbol(SymbolOptions(geometry: home, iconImage: 'nk-home', iconSize: 0.42, iconAnchor: 'center'));
    } else {
      await c.addCircle(CircleOptions(geometry: home, circleRadius: 9, circleColor: '#2E7D32', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
    }
    _ready = true;
    await _fit();
    await _move();
  }

  /// Camera shows home, shop and scooter together.
  Future<void> _fit() async {
    final c = _c;
    if (c == null) return;
    final pts = <LatLng>[
      LatLng(widget.homeLat, widget.homeLng),
      if (_hasShop) LatLng(widget.shopLat!, widget.shopLng!),
      if (widget.riderLat != null) LatLng(widget.riderLat!, widget.riderLng!),
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

  Future<void> _move() async {
    final c = _c;
    if (!_ready || c == null || widget.riderLat == null) return;
    final raw = LatLng(widget.riderLat!, widget.riderLng!);
    final snap = _snap(raw);
    final to = snap?.$1 ?? raw;
    if (_ahead != null && snap != null) {
      await c.updateLine(_ahead!, LineOptions(geometry: [to, ..._route.sublist(snap.$2 + 1)]));
    }
    if (_rider == null) {
      _shown = to;
      _rider = await c.addSymbol(_icon
          ? SymbolOptions(geometry: to, iconImage: 'nk-bike', iconSize: 0.45, iconAnchor: 'bottom')
          : SymbolOptions(geometry: to, textField: '🛵', textSize: 24));
      await _fit();
      return;
    }
    // Slide from where it is drawn to the new point: ~12 frames over 2.5 s.
    final from = _shown ?? to;
    _anim?.cancel();
    var i = 0;
    const steps = 12;
    _anim = Timer.periodic(const Duration(milliseconds: 210), (t) async {
      i++;
      final f = i / steps;
      final p = LatLng(from.latitude + (to.latitude - from.latitude) * f, from.longitude + (to.longitude - from.longitude) * f);
      _shown = p;
      if (i >= steps) t.cancel();
      if (_rider != null && mounted) await c.updateSymbol(_rider!, SymbolOptions(geometry: p));
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.riderLat == null ? null : _dist(widget.homeLat, widget.homeLng, widget.riderLat!, widget.riderLng!);
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
              MapLibreMap(
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
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Color(0xFF21331B), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      d == null
                          ? tr('On the way from {0}', [widget.storeName])
                          : tr('On the way · {0} m away · about {1} min', [d.round(), (d / 250).ceil().clamp(1, 30)]),
                      maxLines: 2,
                      style: body(11.5, color: kBrand, weight: FontWeight.w800)),
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
