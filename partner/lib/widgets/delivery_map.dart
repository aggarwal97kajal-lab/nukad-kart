import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../ola.dart';
import '../ui.dart';

/// Delivery person's map: the customer's door (red pin) and this phone's own position (blue dot).
class DeliveryMap extends StatefulWidget {
  final double lat, lng;
  const DeliveryMap({super.key, required this.lat, required this.lng});
  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  late final Future<String> _style = OlaMaps.style(dark: gDark, lang: 'en');
  MapLibreMapController? _c;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kOkBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.wifi_tethering, size: 16, color: kAct),
          const SizedBox(width: 6),
          Expanded(child: Text(t('Sharing your location with the customer'), style: tx(12, weight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 240,
          child: FutureBuilder<String>(
            future: _style,
            builder: (context, snap) => !snap.hasData
                ? Container(color: kSurf, alignment: Alignment.center, child: snap.hasError ? Text(t('Map not available')) : const CircularProgressIndicator())
                : MapLibreMap(
                    styleString: snap.data!,
                    initialCameraPosition: CameraPosition(target: LatLng(widget.lat, widget.lng), zoom: 15.5),
                    myLocationEnabled: true,
                    myLocationRenderMode: MyLocationRenderMode.normal,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    onMapCreated: (c) => _c = c,
                    onStyleLoadedCallback: () => _c?.addCircle(CircleOptions(
                        geometry: LatLng(widget.lat, widget.lng), circleRadius: 10, circleColor: '#A32D2D', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3)),
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
                  ),
          ),
        ),
      ),
    ]);
  }
}
