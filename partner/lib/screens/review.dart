import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../api.dart';
import '../ui.dart';
import 'docs.dart';
import 'home.dart';

/// Admin: partners waiting for verification.
class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});
  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  List<Map<String, dynamic>> list = [];
  bool all = false, _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/admin/partners${all ? '?status=ALL' : ''}');
      list = ((r['partners'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('Partners to verify', actions: [
        TextButton(
            onPressed: () {
              all = !all;
              _load();
            },
            child: Text(all ? 'Only waiting' : 'Show all')),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (list.isEmpty) Text('Nobody is waiting right now.', style: tx(14, color: kMute)),
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => PartnerReviewScreen(p: p)));
                        _load();
                      },
                      child: Box(
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${p['name']}', style: tx(15, weight: FontWeight.w800)),
                              Text('${p['kind'] == 'thela' ? 'Thela' : 'Shop'} · ${p['phone']} · ${(p['docs'] as List).length} documents',
                                  style: tx(12, color: kMute)),
                            ]),
                          ),
                          pill('${p['status']}'.toUpperCase(),
                              color: p['status'] == 'active' ? kAct : (p['status'] == 'rejected' ? kRed : kAmb),
                              bg: p['status'] == 'active' ? kOkBg : (p['status'] == 'rejected' ? kRedBg : kAmbBg)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
    );
  }
}

class PartnerReviewScreen extends StatefulWidget {
  final Map<String, dynamic> p;
  const PartnerReviewScreen({super.key, required this.p});
  @override
  State<PartnerReviewScreen> createState() => _PartnerReviewScreenState();
}

class _PartnerReviewScreenState extends State<PartnerReviewScreen> {
  bool _busy = false;
  String? _opening;

  Future<void> _open(Map<String, dynamic> d) async {
    setState(() => _opening = '${d['id']}');
    try {
      final (bytes, mime) = await api.bytes('/v1/admin/docs/${d['id']}');
      if (!mounted) return;
      if (mime.contains('pdf')) {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/${d['type']}_${d['id']}.pdf');
        await f.writeAsBytes(bytes, flush: true);
        await OpenFilex.open(f.path);
      } else {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Scaffold(
                      appBar: bar(docLabels['${d['type']}']?.$1 ?? 'Document'),
                      backgroundColor: Colors.black,
                      body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
                    )));
      }
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _opening = null);
  }

  Future<void> _decide(bool approve) async {
    String reason = '';
    if (!approve) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ask for changes'),
          content: TextField(controller: c, maxLines: 3, decoration: field('e.g. PAN photo is blurry. Upload a clear one.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send', style: TextStyle(color: kRed))),
          ],
        ),
      );
      if (ok != true) return;
      reason = c.text.trim();
    }
    setState(() => _busy = true);
    try {
      final r = await api.call('POST', '/v1/admin/partners/${widget.p['id']}/${approve ? 'approve' : 'reject'}', approve ? {} : {'reason': reason});
      if (!mounted) return;
      toast(context, approve ? (r['trial'] == true ? 'Approved · 7-day trial started' : 'Approved (trial already used before)') : 'Sent back for changes');
      Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(k, style: tx(12.5, color: kMute))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: tx(13, weight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final docs = ((p['docs'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Scaffold(
      appBar: bar('${p['name']}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network('$apiBase/v1/stores/${p['id']}/photo', height: 200, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 80, color: kSurf, alignment: Alignment.center, child: const Text('No photo'))),
        ),
        const SizedBox(height: 12),
        Box(
          child: Column(children: [
            _row('Type', p['kind'] == 'thela' ? 'Thela' : 'Shop'),
            _row('Owner email', '${p['ownerEmail'] ?? ''}'),
            _row('Mobile', '${p['phone'] ?? ''} (OTP verified)'),
            _row('Address', '${p['address'] ?? ''}'),
            _row('Timings', '${p['opensAt'] ?? ''} – ${p['closesAt'] ?? ''}'),
            _row('PAN', '${p['pan']}'),
            _row('Aadhaar', 'XXXX XXXX ${p['aadhaarLast4']}'),
            _row('GST', '${p['gstType']} ${p['gstin']}'),
            _row('FSSAI', '${p['fssai']}'),
            _row('Agreement', p['agreementSigned'] == true ? 'Signed v${p['agreementVersion']}' : 'Not signed'),
            _row('Status', '${p['status']}${'${p['reviewNote'] ?? ''}'.isNotEmpty ? ' · ${p['reviewNote']}' : ''}'),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Documents', style: tx(15, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final d in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Box(
              child: Row(children: [
                Icon(d['mime'] == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: kAct),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${docLabels['${d['type']}']?.$1 ?? d['type']} · ${sizeText((d['size'] as num).toInt())}',
                      style: tx(13.5, weight: FontWeight.w700)),
                ),
                TextButton(onPressed: _opening != null ? null : () => _open(d), child: Text(_opening == d['id'] ? 'Opening…' : 'View')),
              ]),
            ),
          ),
        Text('Check: names match PAN, PAN on GST certificate matches, Aadhaar last 4 match, photo is a real shop front. Registered ${dateText(((p['createdAt'] ?? 0) as num).toInt())}.',
            style: tx(11.5, color: kMute)),
        const SizedBox(height: 16),
        if (p['status'] == 'review' || p['status'] == 'rejected' || p['status'] == 'pending') ...[
          Btn(_busy ? 'Saving…' : 'Approve · shop can go live', onTap: _busy || p['agreementSigned'] != true ? null : () => _decide(true)),
          const SizedBox(height: 8),
          Btn('Ask for changes', outline: true, color: kRed, onTap: _busy ? null : () => _decide(false)),
        ] else if (p['status'] == 'active')
          Btn('Ask for changes (takes shop offline)', outline: true, color: kRed, onTap: _busy ? null : () => _decide(false)),
      ]),
    );
  }
}
