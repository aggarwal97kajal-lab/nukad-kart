import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';

String todayText([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

/// Vendor agreement: details filled from the account and shop, today's date, typed name + drawn signature.
class AgreementScreen extends StatefulWidget {
  /// true when opened from the menu to look at the signed copy.
  final bool viewOnly;
  const AgreementScreen({super.key, this.viewOnly = false});
  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  Map<String, dynamic>? data;
  String text = '';
  String? _error;
  bool agree = false, _saving = false, _showAll = false, _drawing = false;
  final name = TextEditingController();
  final _pad = GlobalKey<SignaturePadState>();
  final today = todayText();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/agreement');
      final t = await rootBundle.loadString('assets/agreement_v1.txt');
      final party = Map<String, dynamic>.from(r['party'] as Map);
      text = t.replaceAll('{{city}}', '${party['city']}'.isEmpty ? '[city not set]' : '${party['city']}');
      data = r;
      _error = null;
    } on ApiError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get party => Map<String, dynamic>.from(data!['party'] as Map);
  Map<String, dynamic>? get signed => data!['signed'] == null ? null : Map<String, dynamic>.from(data!['signed'] as Map);
  bool get partyReady => '${party['legalName']}'.isNotEmpty && '${party['address']}'.isNotEmpty && '${party['city']}'.isNotEmpty;

  Future<void> _sign() async {
    if (!agree) {
      toast(context, 'Tick “I have read and agree” first.');
      return;
    }
    if (name.text.trim().length < 3) {
      toast(context, 'Type your full name.');
      return;
    }
    final png = await _pad.currentState?.toPng();
    if (png == null) {
      toast(context, 'Sign in the box with your finger.');
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await api.call('POST', '/v1/partner/agreement', {
        'version': data!['version'],
        'agree': true,
        'name': name.text.trim(),
        'signature': base64Encode(png),
        'date': today,
        'device': 'Nukad Partner app',
      });
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
      if (mounted) toast(context, 'Agreement signed · ${r['id']}');
      if (widget.viewOnly && mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: tx(12.5, color: kMute))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: tx(13, weight: FontWeight.w700))),
        ]),
      );

  Widget _section(String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tx(13, color: kAct, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...rows,
          ]),
        ),
      );

  Widget _agreementText() {
    final paras = text.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final shown = _showAll ? paras : paras.take(6).toList();
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p,
                style: RegExp(r'^\d+\.\s+[A-Z]').hasMatch(p) || p == p.toUpperCase()
                    ? tx(13.5, weight: FontWeight.w800)
                    : tx(12.5)),
          ),
        if (!_showAll)
          TextButton(onPressed: () => setState(() => _showAll = true), child: const Text('Read full agreement')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = session.store ?? {};
    return Scaffold(
      appBar: bar('Partner agreement', actions: [
        if (!widget.viewOnly)
          PopupMenuButton<String>(
            onSelected: (_) => session.signOut(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'out', child: Text('Log out'))],
          ),
      ]),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: tx(14))))
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: _drawing ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.all(16),
                  children: [
                  Text('Vendor Registration & Partnership Agreement', style: tx(17, weight: FontWeight.w800)),
                  Text(
                      'Version ${data!['version']} · Date ${signed?['date'] ?? today}${signed != null ? ' · Ref ${signed!['id']}' : ''}',
                      style: tx(12, color: kMute)),
                  const SizedBox(height: 12),
                  _section('FIRST PARTY · PLATFORM', [
                    _row('Legal name', '${party['legalName']}'),
                    _row('Trading name', 'Nukad Kart'),
                    _row('Type', 'Sole proprietorship'),
                    _row('Address', '${party['address']}'),
                    _row('PAN', '${party['pan']}'),
                    _row('Email', '${party['email']}'),
                  ]),
                  Builder(builder: (_) {
                    final v = Map<String, dynamic>.from((signed?['vendor'] ?? data!['vendor']) as Map);
                    return _section('SECOND PARTY · VENDOR (from your account)', [
                      _row('Store name', '${v['storeName']}'),
                      _row('Type', v['kind'] == 'thela' ? 'Thela (moving)' : 'Shop'),
                      _row('Address', '${v['address']}'),
                      _row('Mobile', '${v['phone']}'),
                      _row('Email', '${v['email']}'),
                      _row('GST', switch (v['gstType']) { 'regular' => 'Regular', 'composition' => 'Composition', _ => 'Not registered' }),
                      if (v['gstType'] != 'none') _row('GSTIN', '${v['gstin']}'),
                      _row('FSSAI', '${v['fssai']}'.isEmpty ? 'Not provided' : '${v['fssai']}'),
                    ]);
                  }),
                  _agreementText(),
                  const SizedBox(height: 12),
                  if (signed != null && (widget.viewOnly || s['agreementSigned'] == true)) ...[
                    Box(
                      color: kOkBg,
                      border: kOkBg,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Signed by ${signed!['name']} on ${signed!['date']}', style: tx(14, weight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Container(
                          color: Colors.white,
                          height: 90,
                          width: double.infinity,
                          child: Image.memory(base64Decode('${signed!['signature']}'), fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 6),
                        Text('Reference ${signed!['id']} · version ${signed!['version']}', style: tx(11.5, color: kMute)),
                      ]),
                    ),
                  ] else if (!partyReady) ...[
                    Box(
                      color: kAmbBg,
                      border: const Color(0xFFFAC775),
                      child: Text(
                          session.admin
                              ? 'Fill the platform details (legal name, address, city) in Admin → Agreement details before anyone signs.'
                              : 'The agreement is being prepared. Please check again in a little while.',
                          style: tx(13, weight: FontWeight.w600)),
                    ),
                  ] else ...[
                    Text('Type your full name', style: tx(12.5, color: kMute, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: field('Name as on PAN / Aadhaar')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Text('Sign here with your finger', style: tx(12.5, color: kMute, weight: FontWeight.w700))),
                      TextButton(onPressed: () => _pad.currentState?.clear(), child: const Text('Clear')),
                    ]),
                    SignaturePad(key: _pad, onActive: (on) => setState(() => _drawing = on)),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: agree,
                      onChanged: (v) => setState(() => agree = v == true),
                      title: Text('I have read and agree to this agreement, the details above are true, and I am allowed to sign for this business.',
                          style: tx(13)),
                    ),
                    Text('Date of signing: $today (today)', style: tx(12, color: kMute)),
                    const SizedBox(height: 12),
                    Btn(_saving ? 'Signing…' : 'Accept and sign', onTap: _saving ? null : _sign),
                  ],
                  const SizedBox(height: 20),
                ]),
    );
  }
}

/// Finger signature box. [toPng] returns null when nothing is drawn.
class SignaturePad extends StatefulWidget {
  final ValueChanged<bool>? onActive;
  const SignaturePad({super.key, this.onActive});
  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = const Size(300, 160);

  void clear() => setState(_strokes.clear);

  Future<Uint8List?> toPng() async {
    final points = _strokes.fold<int>(0, (n, s) => n + s.length);
    if (points < 8) return null;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SigPainter(_strokes).paint(c, _size);
    final img = await rec.endRecording().toImage(_size.width.round(), _size.height.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = Size(box.maxWidth, 160);
      return Container(
        height: 160,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kAct, width: 1.5)),
        // Raw pointer events, so the page doesn't scroll while signing.
        child: Listener(
          onPointerDown: (e) {
            widget.onActive?.call(true);
            setState(() => _strokes.add([e.localPosition]));
          },
          onPointerMove: (e) => setState(() => _strokes.last.add(e.localPosition)),
          onPointerUp: (_) => widget.onActive?.call(false),
          onPointerCancel: (_) => widget.onActive?.call(false),
          child: CustomPaint(painter: _SigPainter(_strokes), size: Size.infinite),
        ),
      );
    });
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SigPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kInk
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.3, p..style = PaintingStyle.fill);
        p.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SigPainter old) => true;
}
