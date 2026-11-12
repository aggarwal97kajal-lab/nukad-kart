import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import '../widgets/map_picker.dart';

/// FSSAI's official registration portal (FoSCoS).
const fssaiPortal = 'https://foscos.fssai.gov.in/';

/// The shop pin must be within this many metres of where the shop photo was taken.
const maxPinDistance = 50.0;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String kind = 'shop';
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final opens = TextEditingController(text: '8 am');
  final closes = TextEditingController(text: '10 pm');
  final fssai = TextEditingController();
  final gstin = TextEditingController();
  String gstType = 'none';
  bool door = true, pickup = true;
  File? photo;
  double? lat, lng, photoLat, photoLng, photoAccuracy;
  int? photoAt;
  bool _locating = false, _saving = false, _photoGps = false;

  double? get pinDistance =>
      lat == null || photoLat == null ? null : Geolocator.distanceBetween(lat!, lng!, photoLat!, photoLng!);

  @override
  void dispose() {
    for (final c in [name, phone, address, opens, closes, fssai, gstin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Position?> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) toast(context, 'Turn on location (GPS) and try again.');
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      if (mounted) toast(context, 'Allow location to set where your shop is.');
      return null;
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final p = await _position();
      if (p != null) {
        lat = p.latitude;
        lng = p.longitude;
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not get the location. Try again outside or near a window.');
    }
    if (mounted) setState(() => _locating = false);
  }

  /// Shop: camera only, stamped with GPS where it was taken. Thela: camera or gallery, no GPS.
  Future<void> _takePhoto([ImageSource source = ImageSource.camera]) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 70);
    if (x == null) return;
    photoAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() {
      photo = File(x.path);
      photoLat = photoLng = photoAccuracy = null;
    });
    if (kind != 'shop') return;
    setState(() => _photoGps = true);
    try {
      final p = await _position();
      if (p != null) {
        photoLat = p.latitude;
        photoLng = p.longitude;
        photoAccuracy = p.accuracy;
        if (lat == null) {
          lat = p.latitude;
          lng = p.longitude;
        }
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not read GPS. Stand outside the shop and take the photo again.');
    }
    if (mounted) setState(() => _photoGps = false);
  }

  void _photoMenu() {
    if (kind == 'shop') {
      _takePhoto();
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(ctx);
              _takePhoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _takePhoto(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  String? get _locationError {
    if (kind != 'shop' || photo == null) return null;
    if (photoLat == null) return _photoGps ? null : 'The photo has no GPS. Turn on location and take the photo again at the shop.';
    if ((photoAccuracy ?? 0) > maxPinDistance) {
      return 'GPS is weak here (±${photoAccuracy!.round()} m). Step outside the shop and take the photo again.';
    }
    final d = pinDistance;
    if (d != null && d > maxPinDistance) {
      final far = d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
      return 'This address is $far from where the shop photo was taken (allowed: ${maxPinDistance.round()} m). Move the pin to your shop or take the photo at the shop.';
    }
    return null;
  }

  Future<void> _save() async {
    if (photo == null) {
      toast(context, kind == 'shop' ? 'Take a photo of the shop front.' : 'Add a photo of your thela.');
      return;
    }
    final locErr = _locationError;
    if (locErr != null) {
      toast(context, locErr);
      return;
    }
    if (kind == 'shop' && address.text.trim().length < 8) {
      toast(context, 'Enter the shop address.');
      return;
    }
    if (lat == null) {
      toast(context, 'Set the shop location.');
      return;
    }
    if (name.text.trim().length < 2) {
      toast(context, 'Enter the shop name.');
      return;
    }
    if (phone.text.length != 10) {
      toast(context, 'Enter a 10-digit phone number.');
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await photo!.readAsBytes();
      final r = await api.call('POST', '/v1/partner/register', {
        'kind': kind,
        'name': name.text.trim(),
        'phone': phone.text,
        'address': address.text.trim(),
        'lat': lat,
        'lng': lng,
        'opensAt': opens.text.trim(),
        'closesAt': closes.text.trim(),
        'door': kind == 'shop' && door,
        'pickup': kind == 'shop' && pickup,
        'fssai': fssai.text.trim(),
        'gstType': gstType,
        'gstin': gstin.text.trim().toUpperCase(),
        'photo': base64Encode(bytes),
        'photoLat': kind == 'shop' ? photoLat : null,
        'photoLng': kind == 'shop' ? photoLng : null,
        'photoAt': photoAt,
      });
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: tx(12.5, color: kMute, weight: FontWeight.w700)),
      );

  Widget _seg(List<(String, String)> opts, String value, ValueChanged<String> on) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          for (final (v, label) in opts)
            Expanded(
              child: GestureDetector(
                onTap: () => on(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: v == value ? kAct : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                  child: Text(label, style: tx(12.5, color: v == value ? Colors.white : kMute, weight: FontWeight.w800)),
                ),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('Register', actions: [TextButton(onPressed: session.signOut, child: Text('Log out', style: tx(13, weight: FontWeight.w700)))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        _label('I am a'),
        _seg([('shop', 'Shop / kirana'), ('thela', 'Thela (moving)')], kind, (v) => setState(() {
              if (v != kind) photo = photoLat = photoLng = photoAccuracy = null;
              kind = v;
            })),
        _label(kind == 'shop' ? 'Shop front photo (camera, at the shop)' : 'Photo of your thela'),
        GestureDetector(
          onTap: _photoMenu,
          child: Container(
            height: 200,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: kSurf, borderRadius: BorderRadius.circular(16), border: Border.all(color: kAct, width: 1.5)),
            child: photo == null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.photo_camera_outlined, color: kAct, size: 40),
                    const SizedBox(height: 6),
                    Text(kind == 'shop' ? 'Take photo' : 'Add photo', style: tx(14, color: kAct, weight: FontWeight.w800)),
                  ])
                : Stack(fit: StackFit.expand, children: [
                    Image.file(photo!, fit: BoxFit.cover),
                    if (kind == 'shop') Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                            _photoGps
                                ? '📍 Reading GPS…'
                                : '📍 ${photoLat?.toStringAsFixed(5) ?? 'no GPS'}, ${photoLng?.toStringAsFixed(5) ?? ''}${photoAccuracy != null ? ' · ±${photoAccuracy!.round()} m' : ''} · tap to retake',
                            style: tx(11.5, color: Colors.white)),
                      ),
                    ),
                  ]),
          ),
        ),
        const SizedBox(height: 8),
        Box(
          color: kAmbBg,
          border: const Color(0xFFF2D3A6),
          child: Text('Real photo only. A wrong or copied photo gets the account blocked.',
              style: tx(12.5, weight: FontWeight.w600)),
        ),
        _label(kind == 'shop' ? 'Shop name' : 'Name customers see'),
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: field('e.g. Sharma General Store')),
        _label('Phone for customers'),
        TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: field('10-digit mobile number')),
        if (kind == 'shop') ...[
          _label('Shop address (search, then put the pin on your shop)'),
          if (photoLat == null)
            Box(color: kSurf, child: Text('Take the shop photo first. The map opens where the photo was taken.', style: tx(13)))
          else
            OlaMapPicker(
              lat: photoLat!,
              lng: photoLng!,
              onChanged: (la, ln, place) => setState(() {
                lat = la;
                lng = ln;
                if (place != null && place.formatted.isNotEmpty) address.text = place.formatted;
              }),
            ),
          const SizedBox(height: 8),
          TextField(
              controller: address,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: field('Shop no., market, sector, pin', label: 'Address (filled from the map, you can edit)')),
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Box(
              color: kRedBg,
              border: const Color(0xFFF7C1C1),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline, color: kRed, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_locationError!, style: tx(12.5, color: kRed, weight: FontWeight.w600))),
              ]),
            ),
          ] else if (pinDistance != null) ...[
            const SizedBox(height: 6),
            Text('✓ Pin is ${pinDistance!.round()} m from the photo spot', style: tx(12, color: kAct, weight: FontWeight.w700)),
          ],
        ] else ...[
          _label('Usual area'),
          Box(
            child: Row(children: [
              const Icon(Icons.my_location, color: kAct),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    lat == null ? 'Stand where you usually sell and tap “Use this spot”.' : 'Set: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                    style: tx(13.5, weight: FontWeight.w600)),
              ),
              TextButton(onPressed: _locating ? null : _locate, child: Text(_locating ? 'Finding…' : 'Use this spot')),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(controller: address, maxLines: 2, decoration: field('Area / market where you sell')),
        ],
        if (kind == 'shop') ...[
          _label('Timings (the shop goes off the app after closing time)'),
          Row(children: [
            Expanded(child: TextField(controller: opens, decoration: field('8 am', label: 'Opens'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: closes, decoration: field('10 pm', label: 'Closes'))),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: door,
              onChanged: (v) => setState(() => door = v),
              title: Text('Home delivery (your own delivery person)', style: tx(14))),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: pickup,
              onChanged: (v) => setState(() => pickup = v),
              title: Text('Customer can pick up at the shop', style: tx(14))),
        ],
        _label('FSSAI registration number (to sell food)'),
        TextField(
            controller: fssai,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
            decoration: field('14 digits · leave empty if you don’t have one')),
        const SizedBox(height: 8),
        Box(
          color: kSurf,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No FSSAI number? You can start with non-food items. Food categories open when you add it.',
                style: tx(12.5)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(fssaiPortal), mode: LaunchMode.externalApplication),
              child: Text('How to get FSSAI registration → foscos.fssai.gov.in',
                  style: tx(13, color: kAct, weight: FontWeight.w800)),
            ),
          ]),
        ),
        _label('GST'),
        _seg([('none', 'No GST'), ('regular', 'GST (Regular)'), ('composition', 'Composition')], gstType,
            (v) => setState(() => gstType = v)),
        if (gstType != 'none') ...[
          const SizedBox(height: 8),
          TextField(
              controller: gstin,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(15)],
              decoration: field('GSTIN, e.g. 07ABCDE1234F1Z5')),
        ],
        const SizedBox(height: 22),
        Btn(_saving ? 'Saving…' : 'Save and continue', onTap: _saving || _locationError != null ? null : _save),
      ]),
    );
  }
}
