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
import '../ola.dart';
import '../prefs.dart';

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
  String kind = prefs.kind == 'thela' ? 'thela' : 'shop';
  final name = TextEditingController();
  final shopNo = TextEditingController();
  final landmark = TextEditingController();
  final address = TextEditingController(); // thela: area where they sell
  final pan = TextEditingController();
  final aadhaar4 = TextEditingController();
  OlaPlace? place; // area, city, state, PIN from the map pin (can't be typed)
  final opens = TextEditingController(text: tr('8 am'));
  final closes = TextEditingController(text: tr('10 pm'));
  final fssai = TextEditingController();
  final gstin = TextEditingController();
  String gstType = 'none';
  bool door = true, pickup = true;
  File? photo;
  double? lat, lng, photoLat, photoLng, photoAccuracy;
  int? photoAt;
  bool _locating = false, _saving = false, _photoGps = false;
  bool get editing => session.store != null;

  @override
  void initState() {
    super.initState();
    final st = session.store;
    if (st == null) return;
    // Fixing details after Nukad team asked for changes: start from what was sent.
    kind = '${st['kind']}' == 'thela' ? 'thela' : 'shop';
    name.text = '${st['name'] ?? ''}';
    opens.text = '${st['opensAt'] ?? ''}';
    closes.text = '${st['closesAt'] ?? ''}';
    fssai.text = '${st['fssai'] ?? ''}';
    gstType = '${st['gstType'] ?? 'none'}';
    gstin.text = '${st['gstin'] ?? ''}';
    pan.text = '${st['pan'] ?? ''}';
    aadhaar4.text = '${st['aadhaarLast4'] ?? ''}';
    door = st['door'] != false;
    pickup = st['pickup'] != false;
    final a = Map<String, dynamic>.from((st['addr'] as Map?) ?? {});
    shopNo.text = '${a['shop'] ?? ''}';
    landmark.text = '${a['landmark'] ?? ''}';
    if (kind == 'thela') address.text = '${st['address'] ?? ''}';
    lat = (st['lat'] as num?)?.toDouble();
    lng = (st['lng'] as num?)?.toDouble();
    if ('${a['city'] ?? ''}'.isNotEmpty) {
      place = OlaPlace(area: '${a['area']}', city: '${a['city']}', state: '${a['state']}', pin: '${a['pin']}');
    }
  }

  double? get pinDistance =>
      lat == null || photoLat == null ? null : Geolocator.distanceBetween(lat!, lng!, photoLat!, photoLng!);

  @override
  void dispose() {
    for (final c in [name, shopNo, landmark, address, pan, aadhaar4, opens, closes, fssai, gstin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Position?> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) toast(context, tr('Turn on location (GPS) and try again.'));
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      if (mounted) toast(context, tr('Allow location to set where your shop is.'));
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
      if (mounted) toast(context, tr('Could not get the location. Try again outside or near a window.'));
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
      if (mounted) toast(context, tr('Could not read GPS. Stand outside the shop and take the photo again.'));
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
            title: Text(tr('Take photo')),
            onTap: () {
              Navigator.pop(ctx);
              _takePhoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('Choose from gallery')),
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
    if (kind != 'shop' || photo == null) return null; // editing without a new photo: the server checks the saved one
    if (photoLat == null) return _photoGps ? null : tr('The photo has no GPS. Turn on location and take the photo again at the shop.');
    if ((photoAccuracy ?? 0) > maxPinDistance) {
      return tr('GPS is weak here (±{0} m). Step outside the shop and take the photo again.', [photoAccuracy!.round()]);
    }
    final d = pinDistance;
    if (d != null && d > maxPinDistance) {
      final far = d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
      return tr('This address is {0} from where the shop photo was taken (allowed: {1} m). Move the pin to your shop or take the photo at the shop.', [far, maxPinDistance.round()]);
    }
    return null;
  }

  Future<void> _save() async {
    if (photo == null && !editing) {
      toast(context, kind == 'shop' ? tr('Take a photo of the shop front.') : tr('Add a photo of your thela.'));
      return;
    }
    if (kind == 'shop' && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan.text.trim().toUpperCase())) {
      toast(context, tr('Enter a valid PAN (example: ABCDE1234F).'));
      return;
    }
    if (aadhaar4.text.length != 4) {
      toast(context, tr('Enter the last 4 digits of Aadhaar.'));
      return;
    }
    final locErr = _locationError;
    if (locErr != null) {
      toast(context, locErr);
      return;
    }
    if (kind == 'shop' && shopNo.text.trim().isEmpty) {
      toast(context, tr('Enter the shop number.'));
      return;
    }
    if (kind == 'shop' && (place == null || place!.pin.length != 6)) {
      toast(context, tr('The map could not find the PIN here. Move the pin a little.'));
      return;
    }
    if (lat == null && kind == 'thela') {
      // Thela: where they are now, only as a starting point. On the map a thela shows at its live location while LIVE.
      await _locate();
    }
    if (lat == null) {
      if (mounted) toast(context, kind == 'shop' ? tr('Set the shop location.') : tr('Turn on location (GPS) and try again.'));
      return;
    }
    if (name.text.trim().length < 2) {
      toast(context, tr('Enter the shop name.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = photo == null ? null : await photo!.readAsBytes();
      final r = await api.call('POST', '/v1/partner/register', {
        'kind': kind,
        'name': name.text.trim(),
        'address': address.text.trim(),
        'pan': kind == 'shop' ? pan.text.trim().toUpperCase() : '',
        'aadhaarLast4': aadhaar4.text,
        'addr': {
          'shop': shopNo.text.trim(),
          'landmark': landmark.text.trim(),
          'area': place?.area ?? '',
          'city': place?.city ?? '',
          'state': place?.state ?? '',
          'pin': place?.pin ?? '',
        },
        'lat': lat,
        'lng': lng,
        'opensAt': opens.text.trim(),
        'closesAt': closes.text.trim(),
        'door': kind == 'shop' && door,
        'pickup': kind == 'shop' && pickup,
        'fssai': kind == 'shop' ? fssai.text.trim() : '',
        'gstType': kind == 'shop' ? gstType : 'none',
        'gstin': gstin.text.trim().toUpperCase(),
        if (bytes != null) 'photo': base64Encode(bytes),
        'photoLat': kind == 'shop' ? photoLat : null,
        'photoLng': kind == 'shop' ? photoLng : null,
        'photoAt': photoAt,
      });
      final wasEditing = editing;
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
      if (wasEditing && mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        toast(context, tr('Details saved. Tap “Send for verification” when ready.'));
        return;
      }
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _locked(String t, {IconData icon = Icons.lock_outline}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: kLocked, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLockedLine)),
        child: Row(children: [
          Icon(icon, size: 16, color: kMute),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: tx(13.5, weight: FontWeight.w600))),
        ]),
      );

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
                  child: Text(label, style: tx(12.5, color: v == value ? kOnAct : kMute, weight: FontWeight.w800)),
                ),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(editing ? tr('Business details') : tr('Register'), actions: [
        if (!editing) TextButton(onPressed: session.signOut, child: Text(tr('Log out'), style: tx(13, weight: FontWeight.w700)))
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        Text(tr('Step 2 of 5 · Business details'), style: tx(12, color: kMute)),
        Row(children: [
          Icon(kind == 'shop' ? Icons.storefront_outlined : Icons.shopping_cart_outlined, color: kAct),
          const SizedBox(width: 8),
          Expanded(child: Text(kind == 'shop' ? tr('Shop / kirana') : tr('Thela (moving)'), style: tx(15, weight: FontWeight.w800))),
          if (!editing)
            TextButton(
              onPressed: () => setState(() {
                kind = kind == 'shop' ? 'thela' : 'shop';
                prefs.setKind(kind);
                photo = photoLat = photoLng = photoAccuracy = null;
              }),
              child: Text(kind == 'shop' ? tr('I have a thela') : tr('I have a shop')),
            ),
        ]),
        _label(kind == 'shop' ? tr('Shop front photo (camera, at the shop)') : tr('Photo of your thela')),
        GestureDetector(
          onTap: _photoMenu,
          child: Container(
            height: 200,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: kSurf, borderRadius: BorderRadius.circular(16), border: Border.all(color: kAct, width: 1.5)),
            child: photo == null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_camera_outlined, color: kAct, size: 40),
                    const SizedBox(height: 6),
                    Text(editing ? tr('Saved photo kept · tap to take a new one') : (kind == 'shop' ? tr('Take photo') : tr('Add photo')),
                        style: tx(14, color: kAct, weight: FontWeight.w800)),
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
                                ? tr('📍 Reading GPS…')
                                : tr('📍 {0}, {1}{2} · tap to retake', [photoLat?.toStringAsFixed(5) ?? 'no GPS', photoLng?.toStringAsFixed(5) ?? '', photoAccuracy != null ? ' · ±${photoAccuracy!.round()} m' : '']),
                            style: tx(11.5, color: Colors.white)),
                      ),
                    ),
                  ]),
          ),
        ),
        const SizedBox(height: 8),
        Box(
          color: kAmbBg,
          border: kAmbLine,
          child: Text(tr('Real photo only. A wrong or copied photo gets the account blocked.'),
              style: tx(12.5, weight: FontWeight.w600)),
        ),
        _label(kind == 'shop' ? tr('Shop name') : tr('Name customers see')),
        TextField(controller: name, textCapitalization: TextCapitalization.words,
            decoration: field(kind == 'shop' ? tr('e.g. Sharma General Store') : tr('e.g. Raju Fresh Sabzi'))),
        _label(tr('Phone for customers (verified)')),
        _locked('+91 ${session.phone}', icon: Icons.verified),
        if (kind == 'shop') ...[
          _label(tr('Shop address (search, then put the pin on your shop)')),
          if (photoLat == null && !(editing && photo == null && lat != null))
            Box(color: kSurf, child: Text(tr('Take the shop photo first. The map opens where the photo was taken.'), style: tx(13)))
          else
            OlaMapPicker(
              lat: photoLat ?? lat!,
              lng: photoLng ?? lng!,
              onChanged: (la, ln, p) => setState(() {
                lat = la;
                lng = ln;
                if (p != null) place = p;
              }),
            ),
          const SizedBox(height: 8),
          TextField(controller: shopNo, decoration: field(tr('Shop No. 7, Ground floor'), label: tr('Shop no. / floor (you type)'))),
          const SizedBox(height: 8),
          TextField(controller: landmark, decoration: field(tr('Near metro pillar 812'), label: tr('Landmark (you type)'))),
          const SizedBox(height: 8),
          Text(tr('From the map pin (can’t be typed)'), style: tx(11.5, color: kMute, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          _locked(place == null
              ? tr('Move the pin to your shop')
              : [place!.area, place!.city, [place!.state, place!.pin].where((x) => x.isNotEmpty).join(' ')].where((x) => x.isNotEmpty).join(' · '),
              icon: Icons.lock_outline),
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Box(
              color: kRedBg,
              border: kRedLine,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error_outline, color: kRed, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_locationError!, style: tx(12.5, color: kRed, weight: FontWeight.w600))),
              ]),
            ),
          ] else if (pinDistance != null) ...[
            const SizedBox(height: 6),
            Text(tr('✓ Pin is {0} m from the photo spot', [pinDistance!.round()]), style: tx(12, color: kAct, weight: FontWeight.w700)),
          ],
        ],
        if (kind == 'shop') ...[
          _label(tr('Timings (the shop goes off the app after closing time)')),
          Row(children: [
            Expanded(child: TextField(controller: opens, decoration: field(tr('8 am'), label: tr('Opens')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: closes, decoration: field(tr('10 pm'), label: tr('Closes')))),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: door,
              onChanged: (v) => setState(() => door = v),
              title: Text(tr('Home delivery (your own delivery person)'), style: tx(14))),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: pickup,
              onChanged: (v) => setState(() => pickup = v),
              title: Text(tr('Customer can pick up at the shop'), style: tx(14))),
        ],
        if (kind == 'shop') ...[
        _label(tr('PAN (required)')),
        TextField(
            controller: pan,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
            decoration: field('ABCDE1234F')),
        ],
        _label(tr('Aadhaar · last 4 digits only (required)')),
        TextField(
            controller: aadhaar4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: field('4821').copyWith(prefixText: tr('XXXX XXXX '))),
        const SizedBox(height: 4),
        Text(tr('We never ask for the full Aadhaar number.'), style: tx(11.5, color: kMute)),
        if (kind == 'shop') ...[
        _label(tr('FSSAI registration number (to sell food)')),
        TextField(
            controller: fssai,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
            decoration: field(tr('14 digits · leave empty if you don’t have one'))),
        const SizedBox(height: 8),
        Box(
          color: kSurf,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('No FSSAI number? You can start with non-food items. Food categories open when you add it.'),
                style: tx(12.5)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(fssaiPortal), mode: LaunchMode.externalApplication),
              child: Text(tr('How to get FSSAI registration → foscos.fssai.gov.in'),
                  style: tx(13, color: kAct, weight: FontWeight.w800)),
            ),
          ]),
        ),
        _label('GST'),
        _seg([('none', tr('No GST')), ('regular', tr('GST (Regular)')), ('composition', tr('Composition'))], gstType,
            (v) => setState(() => gstType = v)),
        if (gstType != 'none') ...[
          const SizedBox(height: 8),
          TextField(
              controller: gstin,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(15)],
              decoration: field(tr('GSTIN, e.g. 07ABCDE1234F1Z5'))),
        ],
        ],
        const SizedBox(height: 22),
        Btn(_saving ? tr('Saving…') : tr('Save and continue'), onTap: _saving || _locationError != null ? null : _save),
      ]),
    );
  }
}
