import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../api.dart';
import '../ui.dart';
import '../excel_io.dart';
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
  bool all = false, _loading = true, more = false, _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    try {
      final q = <String>[if (all) 'status=ALL', if (next && list.isNotEmpty) 'before=${list.last['createdAt']}'];
      final r = await api.call('GET', '/v1/admin/partners${q.isEmpty ? '' : '?${q.join('&')}'}');
      final page = ((r['partners'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      list = next ? [...list, ...page] : page;
      more = r['more'] == true;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(tr('Partners to verify'), actions: [
        TextButton(
            onPressed: () {
              all = !all;
              _load();
            },
            child: Text(all ? tr('Only waiting') : tr('Show all'))),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (list.isEmpty) Text(tr('Nobody is waiting right now.'), style: tx(14, color: kMute)),
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
                              Text(tr('{0} · {1} · {2} documents', [p['kind'] == 'thela' ? 'Thela' : 'Shop', p['phone'], (p['docs'] as List).length]),
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
                if (more)
                  TextButton(
                    onPressed: _loadingMore
                        ? null
                        : () async {
                            setState(() => _loadingMore = true);
                            await _load(next: true);
                            if (mounted) setState(() => _loadingMore = false);
                          },
                    child: Text(_loadingMore ? tr('Loading…') : tr('Load more')),
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
  Future<void> _uploadFor() async {
    try {
      final rows = await pickRows();
      if (rows == null || !mounted) return;
      final r = await api.call('POST', '/v1/admin/stores/${widget.p['id']}/products/bulk', {'rows': rows});
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${widget.p['name']}'),
          content: SingleChildScrollView(child: Text(uploadSummary(r))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('OK')))],
        ),
      );
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

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
                      appBar: bar(docLabels['${d['type']}']?.$1 ?? tr('Document')),
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
          title: Text(tr('Ask for changes')),
          content: TextField(controller: c, maxLines: 3, decoration: field(tr('e.g. PAN photo is blurry. Upload a clear one.'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Back'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Send'), style: TextStyle(color: kRed))),
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
      toast(context, approve ? (r['trial'] == true ? tr('Approved · 7-day trial started') : tr('Approved (trial already used before)')) : tr('Sent back for changes'));
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
              errorBuilder: (_, __, ___) => Container(height: 80, color: kSurf, alignment: Alignment.center, child: Text(tr('No photo')))),
        ),
        const SizedBox(height: 12),
        Box(
          child: Column(children: [
            _row(tr('Type'), p['kind'] == 'thela' ? tr('Thela') : tr('Shop')),
            _row(tr('Owner email'), '${p['ownerEmail'] ?? ''}'),
            _row(tr('Mobile'), tr('{0} (OTP verified)', [p['phone'] ?? ''])),
            if (p['kind'] != 'thela') ...[
              _row(tr('Address'), '${p['address'] ?? ''}'),
              _row(tr('Timings'), '${p['opensAt'] ?? ''} – ${p['closesAt'] ?? ''}'),
              _row('PAN', '${p['pan']}'),
            ],
            _row(tr('Aadhaar'), tr('XXXX XXXX {0}', [p['aadhaarLast4']])),
            if (p['kind'] != 'thela') ...[
              _row('GST', '${p['gstType']} ${p['gstin']}'),
              _row('FSSAI', '${p['fssai']}'),
            ],
            _row(tr('Agreement'), p['agreementSigned'] == true ? tr('Signed v{0}', [p['agreementVersion']]) : tr('Not signed')),
            _row(tr('Status'), '${p['status']}${'${p['reviewNote'] ?? ''}'.isNotEmpty ? ' · ${p['reviewNote']}' : ''}'),
          ]),
        ),
        const SizedBox(height: 12),
        Text(tr('Documents'), style: tx(15, weight: FontWeight.w800)),
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
                TextButton(onPressed: _opening != null ? null : () => _open(d), child: Text(_opening == d['id'] ? tr('Opening…') : tr('View'))),
              ]),
            ),
          ),
        Text(
            p['kind'] == 'thela'
                ? tr('Check: Aadhaar last 4 match, the name looks real, photo is a real thela. Registered {0}.', [dateText(((p['createdAt'] ?? 0) as num).toInt())])
                : tr('Check: names match PAN, PAN on GST certificate matches, Aadhaar last 4 match, photo is a real shop front. Registered {0}.', [dateText(((p['createdAt'] ?? 0) as num).toInt())]),
            style: tx(11.5, color: kMute)),
        const SizedBox(height: 16),
        if (p['status'] == 'review' || p['status'] == 'rejected' || p['status'] == 'pending') ...[
          Btn(_busy ? tr('Saving…') : tr('Approve · shop can go live'), onTap: _busy || p['agreementSigned'] != true ? null : () => _decide(true)),
          const SizedBox(height: 8),
          Btn(tr('Ask for changes'), outline: true, color: kRed, onTap: _busy ? null : () => _decide(false)),
        ] else if (p['status'] == 'active')
          Btn(tr('Ask for changes (takes shop offline)'), outline: true, color: kRed, onTap: _busy ? null : () => _decide(false)),
        if (p['kind'] != 'thela') ...[
          const SizedBox(height: 8),
          // Admin fills a shop's products from the shop's Excel (same template as the shop uses).
          Btn(t('Upload products (Excel)'), outline: true, onTap: _busy ? null : _uploadFor),
          TextButton(onPressed: () async {
            final r = await api.call('GET', '/v1/partner/categories');
            await saveTemplate(((r['categories'] as List?) ?? []).map((c) => '${(c as Map)['name']}').toList());
            if (mounted) toast(context, t('Template saved in Downloads.'));
          }, child: Text(t('Download Excel template'))),
        ],
      ]),
    );
  }
}
