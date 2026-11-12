import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../data/demo_data.dart';
import '../l10n.dart';
import '../services/ola_maps.dart';
import '../state/thela_tracker.dart';
import 'thela_live.dart';
import 'ui.dart';

/// Real street map (Ola Maps): the customer's home, the 500 m circle and the thela's live pin.
/// Falls back to the drawn map if the map can't load (no internet / no map key).
class ThelaRealMap extends StatefulWidget {
  final String thelaId;
  final double homeLat, homeLng;
  const ThelaRealMap({super.key, required this.thelaId, required this.homeLat, required this.homeLng});
  @override
  State<ThelaRealMap> createState() => _ThelaRealMapState();
}

class _ThelaRealMapState extends State<ThelaRealMap> {
  late final Future<String> _style = OlaMaps.style(dark: gDark, lang: gLang);
  MapLibreMapController? _c;
  Circle? _thela, _halo;
  bool _ready = false;
  (double, double)? _shown;

  @override
  void initState() {
    super.initState();
    ThelaTracker.instance.addListener(_move);
  }

  @override
  void dispose() {
    ThelaTracker.instance.removeListener(_move);
    super.dispose();
  }

  (double, double)? get _pos {
    for (final t in kThelas) {
      if (t.id == widget.thelaId) return (t.lat, t.lng);
    }
    return null;
  }

  /// 500 m circle as a polygon (map circles are sized in pixels, not metres).
  List<LatLng> _ring(double lat, double lng, double m) {
    final out = <LatLng>[];
    final dLat = m / 111320.0, dLng = m / (111320.0 * math.cos(lat * math.pi / 180));
    for (var i = 0; i <= 64; i++) {
      final a = 2 * math.pi * i / 64;
      out.add(LatLng(lat + dLat * math.sin(a), lng + dLng * math.cos(a)));
    }
    return out;
  }

  Future<void> _onStyle() async {
    final c = _c;
    if (c == null) return;
    final ring = _ring(widget.homeLat, widget.homeLng, 500);
    await c.addFill(FillOptions(geometry: [ring], fillColor: '#F8CB46', fillOpacity: 0.14));
    await c.addLine(LineOptions(geometry: ring, lineColor: '#21331B', lineWidth: 1.6, lineOpacity: 0.8));
    final home = LatLng(widget.homeLat, widget.homeLng);
    await c.addCircle(CircleOptions(geometry: home, circleRadius: 9, circleColor: '#21331B', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
    _ready = true;
    await _move();
  }

  Future<void> _move() async {
    final c = _c, p = _pos;
    if (!_ready || c == null) return;
    if (p == null) {
      if (_thela != null) {
        await c.removeCircle(_thela!);
        await c.removeCircle(_halo!);
        _thela = _halo = null;
      }
      return;
    }
    if (_shown == p && _thela != null) return;
    final at = LatLng(p.$1, p.$2);
    final st = ThelaTracker.instance.of(widget.thelaId).status;
    final col = st == ThelaStatus.wasHere ? '#8A4B00' : '#3B6D11';
    if (_thela == null) {
      _halo = await c.addCircle(CircleOptions(geometry: at, circleRadius: 22, circleColor: col, circleOpacity: 0.22));
      _thela = await c.addCircle(CircleOptions(geometry: at, circleRadius: 11, circleColor: col, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
      // Fit home and thela on screen.
      final sw = LatLng(math.min(at.latitude, widget.homeLat), math.min(at.longitude, widget.homeLng));
      final ne = LatLng(math.max(at.latitude, widget.homeLat), math.max(at.longitude, widget.homeLng));
      await c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), left: 60, top: 60, right: 60, bottom: 60));
    } else {
      await c.updateCircle(_halo!, CircleOptions(geometry: at, circleColor: col));
      await c.updateCircle(_thela!, CircleOptions(geometry: at, circleColor: col));
    }
    _shown = p;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: FutureBuilder<String>(
        future: _style,
        builder: (context, snap) {
          if (snap.hasError) return ThelaLiveMap(thelaId: widget.thelaId, emoji: '🛒');
          if (!snap.hasData) return Container(color: kSurf, alignment: Alignment.center, child: CircularProgressIndicator());
          return Stack(children: [
            MapLibreMap(
              styleString: snap.data!,
              initialCameraPosition: CameraPosition(target: LatLng(widget.homeLat, widget.homeLng), zoom: 15.2),
              onMapCreated: (c) => _c = c,
              onStyleLoadedCallback: _onStyle,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationEnabled: false,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: ListenableBuilder(
                listenable: ThelaTracker.instance,
                builder: (context, _) {
                  final lv = ThelaTracker.instance.of(widget.thelaId);
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Color(0xFF21331B), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        lv.status == ThelaStatus.notAvailable ? t('Not nearby now') : '${lv.d.round()} m · ${thelaStatusLabel(lv.status, lv.seenAgo).replaceAll('● ', '').replaceAll('➜ ', '')}',
                        style: body(11.5, color: kBrand, weight: FontWeight.w800)),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
