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

  // Search
  final _q = TextEditingController();
  final _qFocus = FocusNode();
  Timer? _searchDebounce;
  List<OlaSuggestion> _results = [];
  bool _searching = false;
  int _searchSeq = 0;
  OlaSuggestion? _pending; // picked from search; applied to the next address lookup

  @override
  void initState() {
    super.initState();
    _style = OlaMaps.style(dark: gDark, lang: gLang);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _q.dispose();
    _qFocus.dispose();
    super.dispose();
  }

  void _onQuery(String text) {
    _searchDebounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_searchSeq;
      final t = _c?.cameraPosition?.target;
      final r = await OlaMaps.autocomplete(text, t?.latitude ?? widget.lat, t?.longitude ?? widget.lng);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _results = r;
      });
    });
  }

  Future<void> _pick(OlaSuggestion sug) async {
    _qFocus.unfocus();
    setState(() {
      _q.text = sug.title;
      _results = [];
      _searching = false;
      _looking = true;
    });
    final at = await OlaMaps.locate(sug);
    if (!mounted) return;
    if (at == null) {
      setState(() => _looking = false);
      showToast(context, 'Couldn’t find that place on the map. Try another search.');
      return;
    }
    _pending = sug;
    await _c?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(at.$1, at.$2), 17));
    _idle(); // in case the map was already there and does not report idle
  }

  void _idle() {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () async {
      final t = _c?.cameraPosition?.target;
      if (t == null || !mounted) return;
      setState(() => _looking = true);
      var p = await OlaMaps.reverse(t.latitude, t.longitude);
      if (!mounted) return;
      final sug = _pending;
      _pending = null;
      if (sug != null) p = (p ?? const OlaPlace()).asPicked(title: sug.title, description: sug.description);
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
      TextField(
        controller: _q,
        focusNode: _qFocus,
        onChanged: _onQuery,
        textInputAction: TextInputAction.search,
        style: body(14.5, weight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: t('Search area, street or landmark'),
          hintStyle: body(14, color: kMute),
          prefixIcon: Icon(Icons.search, color: kMute),
          suffixIcon: _searching
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kG)))
              : (_q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, color: kMute),
                      onPressed: () => setState(() {
                            _q.clear();
                            _results = [];
                          }))),
          isDense: true,
          filled: true,
          fillColor: kCard,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLine)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kG, width: 2)),
        ),
      ),
      if (_results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
          child: Column(children: [
            for (final r in _results)
              InkWell(
                onTap: () => _pick(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.place_outlined, size: 18, color: kG),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
                        if (r.subtitle.isNotEmpty)
                          Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: kMute)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        )
      else if (!_searching && _q.text.trim().length >= 3 && _qFocus.hasFocus)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text('No places found. Try a nearby landmark or move the map.', style: body(12, color: kMute)),
        ),
      const SizedBox(height: 8),
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
