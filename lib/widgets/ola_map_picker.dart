import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../l10n.dart';
import '../services/ola_maps.dart';
import 'ui.dart';

/// Ola map with a fixed centre pin. Move the map to put the pin on the door.
/// Calls [onChanged] with the pin position and the address Ola finds there.
class OlaMapPicker extends StatefulWidget {
  final double lat, lng;
  final void Function(double lat, double lng, OlaPlace? place) onChanged;
  final double height;
  const OlaMapPicker({super.key, required this.lat, required this.lng, required this.onChanged, this.height = 230});
  @override
  State<OlaMapPicker> createState() => _OlaMapPickerState();
}

class _OlaMapPickerState extends State<OlaMapPicker> {
  late Future<String> _style;
  MapLibreMapController? _c;
  OlaPlace? _place;
  bool _looking = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _style = OlaMaps.style(dark: gDark, lang: gLang);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _idle() {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () async {
      final t = _c?.cameraPosition?.target;
      if (t == null || !mounted) return;
      setState(() => _looking = true);
      final p = await OlaMaps.reverse(t.latitude, t.longitude);
      if (!mounted) return;
      setState(() {
        _looking = false;
        _place = p;
      });
      widget.onChanged(t.latitude, t.longitude, p);
    });
  }

  Future<void> _myLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showToast(context, 'Allow location to use this, or move the map yourself.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showToast(context, 'Turn on location (GPS) on your phone.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _c?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17));
    } catch (_) {
      if (mounted) showToast(context, 'Could not get your location. Move the map to your door.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: widget.height,
          child: FutureBuilder<String>(
            future: _style,
            builder: (context, snap) {
              if (snap.hasError) {
                return Container(
                  color: kSurf,
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.map_outlined, color: kMute, size: 36),
                    SizedBox(height: 6),
                    Text('Map didn’t load. Check your internet.', textAlign: TextAlign.center, style: body(13, color: kMute)),
                    TextButton(
                      onPressed: () => setState(() => _style = OlaMaps.style(dark: gDark, lang: gLang)),
                      child: Text('Try again', style: body(13, color: kG, weight: FontWeight.w700)),
                    ),
                  ]),
                );
              }
              if (!snap.hasData) {
                return Container(color: kSurf, alignment: Alignment.center, child: CircularProgressIndicator(color: kG));
              }
              return Stack(children: [
                MapLibreMap(
                  styleString: snap.data!,
                  initialCameraPosition: CameraPosition(target: LatLng(widget.lat, widget.lng), zoom: 16.5),
                  onMapCreated: (c) => _c = c,
                  onStyleLoadedCallback: _idle,
                  trackCameraPosition: true,
                  onCameraIdle: _idle,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                  },
                ),
                // Fixed pin in the middle; its tip marks the spot.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, -20),
                      child: Icon(Icons.location_on, size: 44, color: Color(0xFFD64545)),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Material(
                    color: kCard,
                    shape: StadiumBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: StadiumBorder(),
                      onTap: _myLocation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.my_location, size: 16, color: kG),
                          SizedBox(width: 6),
                          Text(t('Use my location'), style: body(12.5, color: kG, weight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
      SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.place_outlined, size: 16, color: kMute),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            _looking
                ? 'Finding address…'
                : (_place?.formatted.isNotEmpty == true
                    ? _place!.formatted
                    : 'Move the map so the pin is on your door. Shops within 500 m of the pin are shown.'),
            style: body(12, color: kMute),
          ),
        ),
      ]),
    ]);
  }
}
