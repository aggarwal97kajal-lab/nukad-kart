import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n.dart';
import '../services/otp_service.dart';
import '../services/api.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/ola_map_picker.dart';
import '../services/ola_maps.dart';
import 'address_screen.dart';

/// Shown once after Google sign-in: name, mobile (verified by SMS code) and address.
/// Every field is required. Returns true when saved.
class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});
  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late final TextEditingController name, phone, code, flat, floor, area, pin;
  String state = 'Delhi';
  String city = 'New Delhi';
  String country = 'India';
  Offset pinPos = Offset(0.5, 0.5);
  double lat = 28.7158, lng = 77.1135;
  bool _areaAuto = false;

  // SMS code
  String? _reqId;
  String? _verifiedFor; // the number that was verified
  bool _sending = false, _checking = false;
  String? _codeError;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    name = TextEditingController(text: s.name);
    phone = TextEditingController(text: s.phone);
    code = TextEditingController();
    flat = TextEditingController();
    floor = TextEditingController();
    area = TextEditingController();
    pin = TextEditingController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [name, phone, code, flat, floor, area, pin]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _verified => _verifiedFor != null && _verifiedFor == phone.text;

  bool get _valid =>
      name.text.trim().length >= 2 &&
      _verified &&
      flat.text.trim().isNotEmpty &&
      floor.text.trim().isNotEmpty &&
      area.text.trim().length >= 3 &&
      pin.text.length == 6;

  List<String> get _citiesInState => kCityState.entries.where((e) => e.value == state).map((e) => e.key).toList();

  Future<void> _send() async {
    if (phone.text.length != 10 || _sending) return;
    setState(() {
      _sending = true;
      _codeError = null;
      code.clear();
    });
    final resending = _reqId != null;
    String id;
    try {
      if (resending) {
        await otpService.resend(_reqId!);
        id = _reqId!;
      } else {
        id = await otpService.send(phone.text);
      }
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _reqId = id;
      _resendIn = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 30));
      if (_resendIn == 0) t.cancel();
    });
    final demo = otpService.debugCode(id);
    showToast(context, demo == null ? 'Code sent to +91 ${phone.text}' : 'Demo: your code is $demo (real app sends it by SMS)');
  }

  Future<void> _verify() async {
    if (_reqId == null || code.text.length != otpService.codeLength || _checking) return;
    setState(() => _checking = true);
    bool ok;
    try {
      ok = await otpService.verify(_reqId!, code.text);
    } on OtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _codeError = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (ok) {
        _verifiedFor = phone.text;
        _codeError = null;
        _timer?.cancel();
      } else {
        _codeError = 'Wrong code. Check the SMS and try again.';
      }
    });
  }

  void _fromMap(double la, double ln, OlaPlace? p) {
    setState(() {
      lat = la;
      lng = ln;
      if (p == null) return;
      if (p.pin.length == 6) pin.text = p.pin;
      if (p.area.isNotEmpty && (area.text.trim().isEmpty || _areaAuto)) {
        area.text = p.area;
        _areaAuto = true;
      }
      if (kCityState.containsKey(p.city)) {
        city = p.city;
        state = kCityState[p.city]!;
      }
    });
  }

  bool _saving = false;

  Future<void> _save(AppState s) async {
    if (_saving) return;
    final addr = Address(
      flat: flat.text.trim(),
      floor: floor.text.trim(),
      area: area.text.trim(),
      city: city,
      state: state,
      country: country,
      pin: pin.text,
      name: name.text.trim(),
      phone: phone.text,
      px: pinPos.dx,
      py: pinPos.dy,
      lat: lat,
      lng: lng,
    );
    setState(() => _saving = true);
    // Save on the server too. If it cannot be reached, the details stay on this phone for now.
    if (s.apiToken.isNotEmpty) {
      try {
        final access = otpService.lastAccessToken;
        if (access != null && access.isNotEmpty) {
          try {
            await api.verifyPhone(s.apiToken, access, phone.text);
          } on ApiException catch (e) {
            if (!e.unavailable) rethrow; // phone check not switched on yet: still save the rest
          }
        }
        await api.saveProfile(s.apiToken, name.text.trim(), addr);
      } on ApiException catch (e) {
        if (!e.unavailable) {
          if (!mounted) return;
          setState(() => _saving = false);
          showToast(context, e.code == 'phone_not_verified' || e.code == 'phone_mismatch'
              ? 'This number could not be confirmed. Send a new code and try again.'
              : 'Could not save your details (${e.code}). Try again.');
          if (e.code == 'phone_not_verified' || e.code == 'phone_mismatch') {
            setState(() {
              _verifiedFor = null;
              _reqId = null;
              code.clear();
            });
          }
          return;
        }
      }
    }
    if (!mounted) return;
    s.saveProfile(name.text.trim(), phone.text);
    s.markPhoneVerified();
    s.saveAddress(addr);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final sent = _reqId != null;
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(t('Personal details'), subtitle: 'Signed in as ${s.email}'),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Text('Asked only once. Next time you log in with this Google account, you go straight in.',
            style: body(12.5, color: kMute)),
        _section('Your details'),
        _field('Full name', name, hint: 'Your name'),
        _label('Mobile number'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: phone,
              enabled: !_verified,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (_) => setState(() {
                _reqId = null;
                _codeError = null;
              }),
              style: body(15, weight: FontWeight.w600),
              decoration: _dec('10-digit number', prefix: '+91  '),
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: _verified
                ? OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _verifiedFor = null;
                      _reqId = null;
                    }),
                    icon: Icon(Icons.edit_outlined, size: 16),
                    label: Text('Change'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kMute,
                        side: BorderSide(color: kLine),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )
                : FilledButton(
                    onPressed: phone.text.length == 10 && !_sending && _resendIn == 0 ? _send : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: kG,
                        foregroundColor: kOnG,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(_sending
                        ? 'Sending…'
                        : sent
                            ? (_resendIn > 0 ? 'Resend ${_resendIn}s' : 'Resend OTP')
                            : 'Send OTP'),
                  ),
          ),
        ]),
        if (_verified)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.verified, size: 16, color: Color(0xFF2E7D32)),
              SizedBox(width: 6),
              Text('Mobile number verified', style: body(12.5, color: Color(0xFF2E7D32), weight: FontWeight.w700)),
            ]),
          ),
        AnimatedSize(
          duration: Duration(milliseconds: 220),
          child: (sent && !_verified)
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Enter OTP sent to +91 ${phone.text}'),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: TextField(
                        controller: code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(otpService.codeLength)],
                        onChanged: (_) => setState(() => _codeError = null),
                        style: head(20).copyWith(letterSpacing: 6),
                        decoration: _dec('${otpService.codeLength}-digit code').copyWith(errorText: _codeError),
                      ),
                    ),
                    SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: code.text.length == otpService.codeLength && !_checking ? _verify : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: kG,
                            foregroundColor: kOnG,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(_checking ? 'Checking…' : 'Verify'),
                      ),
                    ),
                  ]),
                ])
              : _verified
                  ? Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(color: Color(0xFF2E7D32), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Verified', style: head(15, color: Colors.white)),
                        ]),
                      ),
                    )
                  : SizedBox.shrink(),
        ),
        _section('Delivery address'),
        OlaMapPicker(lat: lat, lng: lng, onChanged: _fromMap),
        Row(children: [
          Expanded(child: _field('Flat / house no.', flat, hint: 'Flat 12')),
          SizedBox(width: 10),
          Expanded(child: _field('Door / block', floor, hint: 'Block C')),
        ]),
        _field('Area / locality', area, hint: 'Sector 21, Rohini'),
        Row(children: [
          Expanded(
              child: _drop('State', state, kStatesList, (v) {
            setState(() {
              state = v;
              city = _citiesInState.first;
            });
          })),
          SizedBox(width: 10),
          Expanded(child: _drop('City', city, _citiesInState, (v) => setState(() => city = v))),
        ]),
        Row(children: [
          Expanded(child: _drop('Country', country, kCountries, (v) => setState(() => country = v))),
          SizedBox(width: 10),
          Expanded(child: _field('Pin code', pin, hint: '110086', digits: 6)),
        ]),
        SizedBox(height: 12),
        CardBox(
          child: Text(
            '3 orders placed and not taken = account blocked. A block applies to the Google account, '
            'this phone and the mobile number together.',
            style: body(12.5, color: kMute),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: kCard, border: Border(top: BorderSide(color: kLine))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PrimaryButton(_saving ? 'Saving…' : 'Save & proceed', onTap: _valid && !_saving ? () => _save(s) : null),
            if (!_valid) ...[
              SizedBox(height: 6),
              Text(_verified ? 'Fill every field to continue' : 'Verify your mobile number and fill every field',
                  style: body(11.5, color: kMute)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: EdgeInsets.only(top: 20, bottom: 2),
        child: Text(text, style: head(17)),
      );

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 5, top: 12),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: body(12.5, color: kMute, weight: FontWeight.w700)),
          TextSpan(text: ' *', style: body(12.5, color: kRed, weight: FontWeight.w700)),
        ])),
      );

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        isDense: true,
        filled: true,
        fillColor: kCard,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFCFD8D1))),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kG, width: 2)),
      );

  Widget _field(String label, TextEditingController c, {String hint = '', int? digits}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: digits != null ? TextInputType.number : TextInputType.text,
        inputFormatters:
            digits != null ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(digits)] : null,
        style: body(15, weight: FontWeight.w600),
        decoration: _dec(hint),
      ),
    ]);
  }

  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFCFD8D1))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            dropdownColor: kCard,
            icon: Icon(Icons.keyboard_arrow_down, color: kMute),
            style: body(15, weight: FontWeight.w600),
            items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    ]);
  }
}
