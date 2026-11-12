import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/ola_map_picker.dart';
import '../services/ola_maps.dart';

/// Cities in the City dropdown. Cities found on the map are added while the app runs.
final Map<String, String> kCityState = {
  'New Delhi': 'Delhi',
  'Gurugram': 'Haryana',
  'Faridabad': 'Haryana',
  'Noida': 'Uttar Pradesh',
  'Ghaziabad': 'Uttar Pradesh',
  'Lucknow': 'Uttar Pradesh',
  'Jaipur': 'Rajasthan',
  'Mumbai': 'Maharashtra',
  'Pune': 'Maharashtra',
  'Bengaluru': 'Karnataka',
  'Chandigarh': 'Chandigarh',
};
List<String> get kStatesList => kCityState.values.toSet().toList()..sort();

/// Adds a city found on the map so the dropdowns can show it. Returns false if unusable.
bool learnCity(String city, String state) {
  if (city.trim().isEmpty || state.trim().isEmpty) return false;
  kCityState.putIfAbsent(city.trim(), () => state.trim());
  return true;
}
const List<String> kCountries = ['India'];
const List<String> kAddressLabels = ['Home', 'Work', 'Hotel', 'Other'];

/// Header line on Home: "DELIVER TO HOME / WORK / HOTEL / <own name>".
String deliverToLabel(String label) {
  return switch (gLang) {
    'hi' => switch (label) {
        'Home' => 'घर पर डिलीवरी',
        'Work' => 'ऑफ़िस पर डिलीवरी',
        'Hotel' => 'होटल पर डिलीवरी',
        _ => '$label पर डिलीवरी',
      },
    'hg' => '${label.toUpperCase()} PAR DELIVERY',
    _ => 'DELIVER TO ${label.toUpperCase()}',
  };
}

IconData labelIcon(String label) => switch (label) {
      'Home' => Icons.home_outlined,
      'Work' => Icons.work_outline,
      'Hotel' => Icons.hotel_outlined,
      _ => Icons.location_on_outlined,
    };

/// Structured delivery address with a map pin (G04). Returns true when saved.
class AddressFormScreen extends StatefulWidget {
  final bool onboarding;
  final Address? editing;
  const AddressFormScreen({super.key, this.onboarding = false, this.editing});
  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final TextEditingController flat, floor, area, pin, name, phone, other;
  String label = 'Home';
  String city = 'New Delhi';
  String state = 'Delhi';
  String country = 'India';
  Offset pinPos = Offset(0.5, 0.5);
  double lat = 28.7158, lng = 77.1135;
  bool _areaAuto = false;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    final e = widget.editing;
    flat = TextEditingController(text: e?.flat ?? '');
    floor = TextEditingController(text: e?.floor ?? '');
    area = TextEditingController(text: e?.area ?? '');
    pin = TextEditingController(text: e?.pin ?? '');
    name = TextEditingController(text: e?.name ?? s.name);
    phone = TextEditingController(text: e?.phone ?? s.phone);
    final custom = e != null && !kAddressLabels.contains(e.label);
    label = e == null ? 'Home' : (custom ? 'Other' : e.label);
    other = TextEditingController(text: custom ? e.label : '');
    if (e != null) {
      learnCity(e.city, e.state);
      city = kCityState.containsKey(e.city) ? e.city : city;
      state = kStatesList.contains(e.state) ? e.state : state;
      pinPos = Offset(e.px, e.py);
      lat = e.lat;
      lng = e.lng;
    }
  }

  @override
  void dispose() {
    for (final c in [flat, floor, area, pin, name, phone, other]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      flat.text.trim().isNotEmpty &&
      area.text.trim().length >= 3 &&
      pin.text.length == 6 &&
      name.text.trim().length >= 2 &&
      phone.text.length == 10 &&
      (label != 'Other' || other.text.trim().length >= 2);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(widget.onboarding ? 'Almost done' : t('Delivery address'),
          subtitle: s.signedIn ? 'Signed in as ${s.email}' : null),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        if (widget.onboarding) ...[
          Text('Where should we deliver?', style: head(20)),
          SizedBox(height: 4),
          Text('Asked only once. Next time you log in with this Google account, you go straight in.',
              style: body(12.5, color: kMute)),
          SizedBox(height: 12),
        ],
        OlaMapPicker(lat: lat, lng: lng, onChanged: _fromMap),
        Row(children: [
          Expanded(child: _field('Flat / house no.', flat, hint: 'Flat 12')),
          SizedBox(width: 10),
          Expanded(child: _field('Floor / block', floor, hint: 'Block C', req: false)),
        ]),
        _field('Area / locality', area, hint: 'Sector 21, Rohini'),
        Row(children: [
          Expanded(
              child: _drop('City', city, kCityState.keys.toList(), (v) {
            setState(() {
              city = v;
              state = kCityState[v] ?? state;
            });
          })),
          SizedBox(width: 10),
          Expanded(child: _drop('State', state, kStatesList, (v) => setState(() => state = v))),
        ]),
        Row(children: [
          Expanded(child: _drop('Country', country, kCountries, (v) => setState(() => country = v))),
          SizedBox(width: 10),
          Expanded(child: _field('Pin code', pin, hint: '110086', digits: 6)),
        ]),
        _label('Save address as', true),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in kAddressLabels)
            ChoiceChip(
              avatar: Icon(labelIcon(l), size: 17, color: label == l ? kGText : kMute),
              label: Text(l),
              selected: label == l,
              showCheckmark: false,
              labelStyle: body(13.5, color: label == l ? kGText : kInk, weight: FontWeight.w700),
              selectedColor: kGBg,
              backgroundColor: kCard,
              side: BorderSide(color: label == l ? kG : Color(0xFFCFD8D1), width: label == l ? 2 : 1),
              shape: StadiumBorder(),
              onSelected: (_) => setState(() => label = l),
            ),
        ]),
        if (label == 'Other') ...[
          _field('Name this address', other, hint: 'e.g. Mummy ka ghar, PG, Dukaan'),
        ],
        Row(children: [
          Expanded(child: _field('Receiver name', name, hint: 'Your name')),
          SizedBox(width: 10),
          Expanded(child: _field('Mobile', phone, hint: '10 digits', digits: 10)),
        ]),
        SizedBox(height: 12),
        NoteBox('Nukad Kart is live in Rohini, Delhi (pin codes 110085, 110086 and 110089). More areas are coming soon.'),
        if (widget.onboarding) ...[
          SizedBox(height: 10),
          CardBox(
            child: Text(
              '3 orders placed and not taken = account blocked. A block applies to the Google account, '
              'this phone and the mobile number together.',
              style: body(12.5, color: kMute),
            ),
          ),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: kCard, border: Border(top: BorderSide(color: kLine))),
          child: PrimaryButton(widget.onboarding ? 'Save & continue' : 'Save & check shops near me',
              onTap: _valid ? () => _save(s) : null),
        ),
      ),
    );
  }

  void _fromMap(double la, double ln, OlaPlace? p) {
    setState(() {
      lat = la;
      lng = ln;
      if (p == null) return;
      if (p.pin.length == 6) pin.text = p.pin;
      // A place picked from search always fills the boxes; a dragged map fills only empty or auto-filled ones.
      if (p.area.isNotEmpty && (p.picked || area.text.trim().isEmpty || _areaAuto)) {
        area.text = p.area;
        _areaAuto = true;
      }
      if (learnCity(p.city, p.state) || kCityState.containsKey(p.city)) {
        city = p.city;
        state = kCityState[p.city]!;
      }
    });
  }


  void _save(AppState s) {
    final a = Address(
      flat: flat.text.trim(),
      floor: floor.text.trim(),
      area: area.text.trim(),
      city: city,
      state: state,
      country: country,
      pin: pin.text,
      name: name.text.trim(),
      phone: phone.text,
      label: label == 'Other' ? other.text.trim() : label,
      px: pinPos.dx,
      py: pinPos.dy,
      lat: lat,
      lng: lng,
    );
    if (s.name.isEmpty || widget.onboarding) s.saveProfile(a.name, a.phone);
    s.saveAddress(a, replacing: widget.editing);
    Navigator.pop(context, true);
  }

  Widget _label(String text, bool req) => Padding(
        padding: EdgeInsets.only(bottom: 5, top: 12),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: body(12.5, color: kMute, weight: FontWeight.w700)),
          if (req) TextSpan(text: ' *', style: body(12.5, color: kRed, weight: FontWeight.w700)),
        ])),
      );

  Widget _field(String label, TextEditingController c, {String hint = '', bool req = true, int? digits}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label, req),
      TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: digits != null ? TextInputType.number : TextInputType.text,
        inputFormatters:
            digits != null ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(digits)] : null,
        style: body(15, weight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: kCard,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Color(0xFFCFD8D1))),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: kG, width: 2)),
        ),
      ),
    ]);
  }

  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label, true),
      Container(
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(11), border: Border.all(color: Color(0xFFCFD8D1))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            dropdownColor: kCard,
            icon: Icon(Icons.keyboard_arrow_down, color: kMute),
            style: body(15, weight: FontWeight.w600),
            items: [
              for (final i in items)
                DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    ]);
  }
}

/// Demo map: streets drawn in code; tap to move the pin. The real app uses Google Maps.
class DemoMapPicker extends StatelessWidget {
  final Offset pos;
  final ValueChanged<Offset> onChanged;
  const DemoMapPicker({super.key, required this.pos, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            onTapDown: (d) => onChanged(Offset(
                (d.localPosition.dx / c.maxWidth).clamp(0.05, 0.95).toDouble(),
                (d.localPosition.dy / c.maxHeight).clamp(0.1, 0.9).toDouble())),
            onPanUpdate: (d) => onChanged(Offset(
                (d.localPosition.dx / c.maxWidth).clamp(0.05, 0.95).toDouble(),
                (d.localPosition.dy / c.maxHeight).clamp(0.1, 0.9).toDouble())),
            child: CustomPaint(
              size: Size(c.maxWidth, c.maxHeight),
              painter: _MiniMapPainter(pos, gDark),
            ),
          );
        }),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final Offset pos;
  final bool dark;
  _MiniMapPainter(this.pos, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? Color(0xFF1E1E1E) : Color(0xFFF4EFDC));
    final road = Paint()
      ..color = dark ? Color(0xFF2C3D33) : Colors.white
      ..strokeWidth = 10;
    for (final y in [0.3, 0.75]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), road);
    }
    for (final x in [0.25, 0.7]) {
      canvas.drawLine(Offset(size.width * x, 0), Offset(size.width * x, size.height), road);
    }
    final p = Offset(pos.dx * size.width, pos.dy * size.height);
    canvas.drawCircle(p, 46, Paint()..color = Color(0x33F8CB46));
    canvas.drawCircle(
        p,
        46,
        Paint()
          ..color = kG
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final pinPath = Path()
      ..moveTo(p.dx, p.dy)
      ..cubicTo(p.dx - 4, p.dy - 8, p.dx - 12, p.dy - 14, p.dx - 12, p.dy - 22)
      ..arcToPoint(Offset(p.dx + 12, p.dy - 22), radius: Radius.circular(12))
      ..cubicTo(p.dx + 12, p.dy - 14, p.dx + 4, p.dy - 8, p.dx, p.dy)
      ..close();
    canvas.drawPath(pinPath, Paint()..color = Color(0xFFD64545));
    canvas.drawCircle(Offset(p.dx, p.dy - 22), 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => old.pos != pos || old.dark != dark;
}

/// Sheet listing saved addresses, plus "Add new address".
Future<void> showAddressPicker(BuildContext context, {String title = 'Choose delivery location'}) async {
  final s = AppScope.read(context);
  // Returns true for "add new", an Address to edit, or null.
  final res = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: kCard,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
          SizedBox(height: 12),
          Text(title, style: head(19)),
          SizedBox(height: 10),
          if (s.addresses.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Browsing near ${kGuestLocation.short} (${kGuestLocation.pin}).', style: body(13, color: kMute)),
            ),
          for (final a in s.addresses)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  s.useAddress(a);
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: a == s.current ? kGBg : kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: a == s.current ? kG : kLine, width: a == s.current ? 2 : 1),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(labelIcon(a.label), color: kG),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.label.toUpperCase(), style: body(11.5, color: kG, weight: FontWeight.w800)),
                        Text(a.short, style: body(14, weight: FontWeight.w600)),
                        Text('${a.city} ${a.pin}', style: body(12, color: kMute)),
                      ]),
                    ),
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, a),
                      icon: Icon(Icons.edit_outlined, size: 16),
                      label: Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        side: BorderSide(color: kLine, width: 1.5),
                        minimumSize: Size(0, 34),
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          SizedBox(height: 8),
          PrimaryButton('+ Add new address', outline: true, onTap: () => Navigator.pop(ctx, true)),
        ]),
      ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (res == true) {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddressFormScreen()));
  } else if (res is Address) {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddressFormScreen(editing: res)));
  }
}
