import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../l10n.dart';
import '../services/ola_maps.dart';
import 'ui.dart';

/// Real map for a shop delivery: customer's door and the Nukad Kart scooter (the delivery person's phone).
class RiderMap extends StatefulWidget {
  final double homeLat, homeLng;
  final double? riderLat, riderLng;
  final String storeName;
  const RiderMap({super.key, required this.homeLat, required this.homeLng, this.riderLat, this.riderLng, required this.storeName});
  @override
  State<RiderMap> createState() => _RiderMapState();
}

class _RiderMapState extends State<RiderMap> {
  late final Future<String> _style = OlaMaps.style(dark: gDark, lang: gLang);
  MapLibreMapController? _c;
  Symbol? _rider;
  bool _ready = false, _icon = false;

  @override
  void didUpdateWidget(RiderMap old) {
    super.didUpdateWidget(old);
    if (old.riderLat != widget.riderLat || old.riderLng != widget.riderLng) _move();
  }

  Future<void> _onStyle() async {
    final c = _c;
    if (c == null) return;
    // 500 m around the customer's door, same as on the thela map.
    final ring = <LatLng>[];
    final dLat = 500 / 111320.0, dLng = 500 / (111320.0 * math.cos(widget.homeLat * math.pi / 180));
    for (var i = 0; i <= 64; i++) {
      final a = 2 * math.pi * i / 64;
      ring.add(LatLng(widget.homeLat + dLat * math.sin(a), widget.homeLng + dLng * math.cos(a)));
    }
    await c.addFill(FillOptions(geometry: [ring], fillColor: '#F8CB46', fillOpacity: 0.14));
    await c.addLine(LineOptions(geometry: ring, lineColor: '#21331B', lineWidth: 1.6, lineOpacity: 0.8));
    await c.addCircle(CircleOptions(geometry: LatLng(widget.homeLat, widget.homeLng), circleRadius: 9, circleColor: '#21331B', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
    try {
      final b = await rootBundle.load('assets/images/markers/bike.png');
      await c.addImage('nk-bike', b.buffer.asUint8List());
      _icon = true;
    } catch (_) {}
    _ready = true;
    await _move();
  }

  Future<void> _move() async {
    final c = _c;
    if (!_ready || c == null || widget.riderLat == null) return;
    final at = LatLng(widget.riderLat!, widget.riderLng!);
    if (_rider == null) {
      _rider = await c.addSymbol(_icon
          ? SymbolOptions(geometry: at, iconImage: 'nk-bike', iconSize: 0.45, iconAnchor: 'bottom')
          : SymbolOptions(geometry: at, textField: '🛵', textSize: 24));
      const pad = 0.0012;
      final sw = LatLng(math.min(at.latitude, widget.homeLat) - pad, math.min(at.longitude, widget.homeLng) - pad);
      final ne = LatLng(math.max(at.latitude, widget.homeLat) + pad, math.max(at.longitude, widget.homeLng) + pad);
      await c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), left: 40, top: 40, right: 40, bottom: 40));
    } else {
      await c.updateSymbol(_rider!, SymbolOptions(geometry: at));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.riderLat == null ? null : _dist(widget.homeLat, widget.homeLng, widget.riderLat!, widget.riderLng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 280,
        child: FutureBuilder<String>(
          future: _style,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Container(color: kSurf, alignment: Alignment.center,
                  child: snap.hasError ? Text('On the way from ${widget.storeName}', style: head(15)) : CircularProgressIndicator());
            }
            return Stack(children: [
              MapLibreMap(
                styleString: snap.data!,
                initialCameraPosition: CameraPosition(target: LatLng(widget.homeLat, widget.homeLng), zoom: 15.2),
                minMaxZoomPreference: MinMaxZoomPreference(12, 18),
                onMapCreated: (c) => _c = c,
                onStyleLoadedCallback: _onStyle,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Color(0xFF21331B), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      d == null ? 'On the way · scooter shows once the delivery phone sends its location' : 'On the way · ${d.round()} m away · about ${(d / 250).ceil().clamp(1, 30)} min',
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
