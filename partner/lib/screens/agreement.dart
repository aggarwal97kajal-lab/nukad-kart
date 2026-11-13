import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agreement_pdf.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import 'admin.dart';

String todayText([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

/// Agreement data from the server + the text from the app.
class AgreementData {
  final Map<String, dynamic> raw;
  final String text;
  AgreementData(this.raw, this.text);
  Map<String, dynamic> get party => Map<String, dynamic>.from(raw['party'] as Map);
  Map<String, dynamic>? get signed => raw['signed'] == null ? null : Map<String, dynamic>.from(raw['signed'] as Map);
  Map<String, dynamic> get vendor => Map<String, dynamic>.from((signed?['vendor'] ?? raw['vendor']) as Map);
  String get version => '${raw['version']}';
  List<String> get missingParty => [
        if ('${party['legalName']}'.isEmpty) tr('legal name'),
        if ('${party['address']}'.isEmpty) 'address',
        if ('${party['city']}'.isEmpty) tr('court city'),
      ];

  /// A signed copy as the admin sees it (from the saved snapshot), for the same PDF.
  static Future<AgreementData> fromSigned(Map<String, dynamic> a) async {
    final party = Map<String, dynamic>.from((a['party'] as Map?) ?? {});
    final signed = Map<String, dynamic>.from((a['signed'] as Map?) ?? {});
    final t = await rootBundle.loadString('assets/agreement_v1.txt');
    final city = '${party['city'] ?? ''}';
    return AgreementData({'version': a['version'], 'party': party, 'signed': signed, 'vendor': signed['vendor'] ?? {}},
        t.replaceAll('{{city}}', city.isEmpty ? '[city]' : city));
  }

  static Future<AgreementData> load() async {
    final r = await api.call('GET', '/v1/partner/agreement');
    final t = await rootBundle.loadString('assets/agreement_v1.txt');
    final city = '${(r['party'] as Map)['city'] ?? ''}';
    return AgreementData(r, t.replaceAll('{{city}}', city.isEmpty ? '[city]' : city));
  }
}

/// Step 4 (read + two ticks) and step 5 (name, finger signature, today's date).
class AgreementScreen extends StatefulWidget {
  /// true when opened from the menu to look at the signed copy.
  final bool viewOnly;
  const AgreementScreen({super.key, this.viewOnly = false});
  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  AgreementData? data;
  String? _error;
  bool agree = false, authorised = false, signing = false, _saving = false, _showAll = false, _drawing = false;
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
      data = await AgreementData.load();
      _error = null;
    } on ApiError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _sign() async {
    if (name.text.trim().length < 3) {
      toast(context, tr('Type your full name.'));
      return;
    }
    final png = await _pad.currentState?.toPng();
    if (png == null) {
      toast(context, tr('Sign in the box with your finger.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await api.call('POST', '/v1/partner/agreement', {
        'version': data!.version,
        'agree': agree,
        'authorised': authorised,
        'name': name.text.trim(),
        'signature': base64Encode(png),
        'date': today,
        'device': 'Nukad Partner app',
      });
      final fresh = await AgreementData.load();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SignedScreen(data: fresh)));
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
      if (widget.viewOnly && mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _check(bool v, String text, ValueChanged<bool> on) => InkWell(
        onTap: () => on(!v),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(v ? Icons.check_box : Icons.check_box_outline_blank, color: v ? kAct : kMute, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: tx(14.5, weight: FontWeight.w600))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: bar(signing ? tr('Sign agreement') : tr('Partner agreement'), actions: [
        if (!widget.viewOnly)
          PopupMenuButton<String>(
            onSelected: (_) => session.signOut(),
            itemBuilder: (_) => [PopupMenuItem(value: 'out', child: Text(tr('Log out')))],
          ),
      ]),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: tx(14))))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: _drawing ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // A live shop whose name / address / number changed: must sign again before going live.
                    if (!widget.viewOnly && session.store?['status'] == 'active')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Box(
                          color: kSurf,
                          border: kAmb,
                          child: Text(tr('Your details changed. Sign the updated agreement to go live again. Your earlier agreement is kept.'),
                              style: tx(13.5, weight: FontWeight.w800)),
                        ),
                      ),
                    ...(signing ? _signStep(d) : _readStep(d)),
                  ],
                ),
    );
  }

  List<Widget> _readStep(AgreementData d) {
    final signed = d.signed;
    if (signed != null && (widget.viewOnly || session.store?['agreementSigned'] == true)) {
      return [
        AgreementDetails(data: d, showAll: true),
        const SizedBox(height: 12),
        SignedCard(data: d),
      ];
    }
    return [
      if (!widget.viewOnly) Text(tr('Step 4 of 5'), style: tx(12, color: kMute)),
      const SizedBox(height: 6),
      Box(
        color: kSurf,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tr('Vendor Partnership Agreement'), style: tx(16, weight: FontWeight.w800))),
            pill('v${d.version}'),
          ]),
          const SizedBox(height: 4),
          Text(tr('Read the full agreement before accepting. Your acceptance is recorded against your registered business account.'),
              style: tx(12.5, color: kMute)),
        ]),
      ),
      const SizedBox(height: 12),
      AgreementDetails(data: d, showAll: _showAll, onShowAll: () => setState(() => _showAll = true)),
      const SizedBox(height: 12),
      if (d.missingParty.isNotEmpty)
        Box(
          color: kAmbBg,
          border: kAmbLine,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Signing opens soon'), style: tx(15, color: kAmb, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                session.admin
                    ? tr('Nukad Kart details missing: {0}. Fill them so partners can sign.', [d.missingParty.join(', ')])
                    : tr('Nukad Kart’s own legal details are being added. Your documents are saved; come back in a little while and pull down to refresh.'),
                style: tx(13)),
            if (session.admin) ...[
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAmb),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                  _load();
                },
                child: Text(tr('Fill now')),
              ),
            ] else
              TextButton(onPressed: _load, child: Text(tr('Check again'))),
          ]),
        )
      else ...[
        _check(agree, tr('I have read and agree to the Vendor Partnership Agreement.'), (v) => setState(() => agree = v)),
        _check(authorised, tr('I confirm that I am authorised to accept this agreement for my business.'), (v) => setState(() => authorised = v)),
        const SizedBox(height: 12),
        Btn(tr('Continue to sign'), onTap: agree && authorised ? () => setState(() => signing = true) : null),
      ],
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _signStep(AgreementData d) => [
        Text(tr('Step 5 of 5'), style: tx(12, color: kMute)),
        const SizedBox(height: 10),
        Text(tr('Full name (as on PAN)'), style: tx(12.5, color: kMute, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: field(t('Full name'))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(tr('Sign with your finger'), style: tx(12.5, color: kMute, weight: FontWeight.w700))),
          TextButton(onPressed: () => _pad.currentState?.clear(), child: Text(tr('Clear'))),
        ]),
        SignaturePad(key: _pad, onActive: (on) => setState(() => _drawing = on)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kLocked, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 16, color: kMute),
            const SizedBox(width: 8),
            Text(tr('Date: {0} (today)', [today]), style: tx(13.5, weight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        Btn(_saving ? tr('Signing…') : tr('Accept and sign'), onTap: _saving ? null : _sign),
        TextButton(onPressed: _saving ? null : () => setState(() => signing = false), child: Text(tr('Back to agreement'))),
      ];
}

/// Both parties' details + the agreement text.
class AgreementDetails extends StatelessWidget {
  final AgreementData data;
  final bool showAll;
  final VoidCallback? onShowAll;
  const AgreementDetails({super.key, required this.data, this.showAll = false, this.onShowAll});

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

  @override
  Widget build(BuildContext context) {
    final p = data.party, v = data.vendor;
    final paras = data.text.split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    final shown = showAll ? paras : paras.take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Version {0} · Date {1}{2}', [data.version, data.signed?['date'] ?? todayText(), data.signed != null ? ' · Ref ${data.signed!['id']}' : '']),
          style: tx(12, color: kMute)),
      const SizedBox(height: 8),
      _section(tr('FIRST PARTY · PLATFORM'), [
        _row(tr('Legal name'), '${p['legalName']}'),
        _row(tr('Trading name'), 'Nukad Kart'),
        _row(tr('Type'), tr('Sole proprietorship')),
        _row(tr('Address'), '${p['address']}'),
        _row('PAN', '${p['pan']}'),
        _row(tr('Email'), '${p['email']}'),
      ]),
      _section(tr('SECOND PARTY · VENDOR (from your account)'), [
        _row(tr('Store name'), '${v['storeName']}'),
        _row(tr('Type'), v['kind'] == 'thela' ? tr('Thela (moving)') : tr('Shop')),
        _row(tr('Address'), '${v['address']}'),
        _row(tr('Mobile'), '${v['phone']}'),
        _row(tr('Email'), '${v['email']}'),
        _row('PAN', '${v['pan'] ?? ''}'),
        _row(tr('Aadhaar'), '${v['aadhaarLast4'] ?? ''}'.isEmpty ? '' : tr('XXXX XXXX {0}', [v['aadhaarLast4']])),
        _row('GST', switch (v['gstType']) { 'regular' => tr('Regular'), 'composition' => tr('Composition'), _ => tr('Not registered') }),
        if (v['gstType'] != 'none') _row('GSTIN', '${v['gstin']}'),
        _row('FSSAI', '${v['fssai']}'.isEmpty ? tr('Not provided') : '${v['fssai']}'),
      ]),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final x in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(x, style: RegExp(r'^\d+\.\s+[A-Z]').hasMatch(x) ? tx(13.5, weight: FontWeight.w800) : tx(12.5)),
            ),
          if (!showAll && onShowAll != null) TextButton(onPressed: onShowAll, child: Text(tr('Read full agreement'))),
        ]),
      ),
    ]);
  }
}

/// Signature, name, date, reference + PDF download / share.
class SignedCard extends StatefulWidget {
  final AgreementData data;
  const SignedCard({super.key, required this.data});
  @override
  State<SignedCard> createState() => _SignedCardState();
}

class _SignedCardState extends State<SignedCard> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final (path, inDownloads) = await saveAgreementPdf(widget.data);
      if (mounted) {
        showToastAction(context, inDownloads ? tr('Saved to Downloads') : tr('Saved in the app'), tr('Open'), () => openAgreementFile(path));
      }
    } catch (_) {
      if (mounted) toast(context, tr('Could not make the PDF. Try again.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await shareAgreementPdf(widget.data);
    } catch (_) {
      if (mounted) toast(context, tr('Could not share the PDF. Try again.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data.signed!;
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(child: Text(k, style: tx(12.5, color: kMute))),
            Text(v, style: tx(13, weight: FontWeight.w800)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          kv(tr('Reference'), '${s['id']}'),
          kv(tr('Signed by'), '${s['name']}'),
          kv(tr('Date'), signedAtText(s)),
          kv(tr('Version'), '${s['version']}'),
          const Divider(),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _sigBox(t('VENDOR'), '${s['signature']}', '${s['name']}')),
            const SizedBox(width: 8),
            Expanded(child: _sigBox(t('FOR NUKAD KART'), '${widget.data.party['signature'] ?? ''}', '${widget.data.party['signName'] ?? ''}')),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Btn(tr('Download PDF'), outline: true, onTap: _busy ? null : _download)),
        const SizedBox(width: 10),
        Expanded(child: Btn(tr('Share'), outline: true, onTap: _busy ? null : _share)),
      ]),
    ]);
  }
}

Widget _sigBox(String who, String b64, String name) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(who, style: tx(10.5, color: kMute, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      Container(
        height: 70,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: b64.isEmpty
            ? Center(child: Text(t('Not added yet'), style: tx(11, color: const Color(0xFF5E6A55))))
            : Image.memory(base64Decode(b64), fit: BoxFit.contain),
      ),
      const SizedBox(height: 4),
      Text(name, maxLines: 2, style: tx(11.5, weight: FontWeight.w700)),
    ]);

String signedAtText(Map<String, dynamic> s) {
  final at = DateTime.fromMillisecondsSinceEpoch(((s['acceptedAt'] as num?) ?? 0).toInt() * 1000);
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '${s['date']}, $h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}';
}

/// Shown right after signing.
class SignedScreen extends StatelessWidget {
  final AgreementData data;
  const SignedScreen({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(tr('Agreement signed')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 10),
        Icon(Icons.check_circle, color: kAct, size: 64),
        const SizedBox(height: 6),
        Text(tr('Signed'), textAlign: TextAlign.center, style: tx(20, weight: FontWeight.w800)),
        Text(tr('Nukad Kart team will now verify your documents.'), textAlign: TextAlign.center, style: tx(13, color: kMute)),
        const SizedBox(height: 16),
        SignedCard(data: data),
        const SizedBox(height: 16),
        Btn(tr('Go to my shop'), onTap: () => Navigator.pop(context)),
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

  Future<Uint8List?> toPng({bool transparent = false}) async {
    final points = _strokes.fold<int>(0, (n, s) => n + s.length);
    if (points < 8) return null;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    if (!transparent) c.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SigPainter(_strokes).paint(c, _size);
    final img = await rec.endRecording().toImage(_size.width.round(), _size.height.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  bool _penUp = false;

  bool _inside(Offset o) => o.dx >= 2 && o.dy >= 2 && o.dx <= _size.width - 2 && o.dy <= _size.height - 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = Size(box.maxWidth, 160);
      return Container(
        height: 160,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kAct, width: 1.5)),
        // The ink stays inside the box: drawing outside is not recorded, and the line starts again when the finger comes back in.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          // Raw pointer events, so the page doesn't scroll while signing.
          child: Listener(
            onPointerDown: (e) {
              widget.onActive?.call(true);
              _penUp = false;
              setState(() => _strokes.add([e.localPosition]));
            },
            onPointerMove: (e) {
              final o = e.localPosition;
              if (!_inside(o)) {
                _penUp = true;
                return;
              }
              setState(() {
                if (_penUp || _strokes.isEmpty) {
                  _strokes.add([o]);
                  _penUp = false;
                } else {
                  _strokes.last.add(o);
                }
              });
            },
            onPointerUp: (_) => widget.onActive?.call(false),
            onPointerCancel: (_) => widget.onActive?.call(false),
            child: CustomPaint(painter: _SigPainter(_strokes), size: Size.infinite),
          ),
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
      ..color = const Color(0xFF14203C) // ink pen, on the white box in both themes
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
