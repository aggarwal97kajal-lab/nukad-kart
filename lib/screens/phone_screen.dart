import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _addr = TextEditingController(text: 'Flat 12, Block C, Sector 21');

  bool get _valid => _name.text.trim().length >= 2 && _phone.text.length == 10 && _addr.text.trim().length >= 5;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCFD8D1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kG, width: 2)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: t, style: body(12.5, color: const Color(0xFF3B4740), weight: FontWeight.w700)),
          TextSpan(text: ' *', style: body(12.5, color: kRed, weight: FontWeight.w700)),
        ])),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar('Almost done', subtitle: 'Signed in as ${s.email}'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 24), children: [
        Text('Your phone number', style: head(20)),
        const SizedBox(height: 6),
        Text('Stores and sellers use it to call you about your order. It is required to place orders.',
            style: body(13.5, color: kMute)),
        _label('Mobile number'),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => setState(() {}),
          decoration: _dec('10-digit number', prefix: '+91  '),
        ),
        _label('Name'),
        TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: _dec('Your name')),
        _label('Delivery address'),
        TextField(controller: _addr, onChanged: (_) => setState(() {}), decoration: _dec('House, block, sector')),
        const SizedBox(height: 16),
        const CardBox(
          child: Text(
            '3 orders placed and not taken = account blocked. A block applies to the Google account, '
            'this phone and the mobile number together.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: kMute, height: 1.45),
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton('Save & continue',
            onTap: _valid
                ? () {
                    s.saveProfile(_name.text.trim(), _phone.text, _addr.text.trim());
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
                  }
                : null),
      ]),
    );
  }
}
