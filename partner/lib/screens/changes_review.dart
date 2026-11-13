import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'admin_docs.dart';

/// Admin: live shops / thelas asking to change name, address (map pin) or photo.
/// Approve → applied, and the partner must sign the updated agreement before going live again.
class ChangesReviewScreen extends StatefulWidget {
  const ChangesReviewScreen({super.key});
  @override
  State<ChangesReviewScreen> createState() => _ChangesReviewScreenState();
}

class _ChangesReviewScreenState extends State<ChangesReviewScreen> {
  List<Map<String, dynamic>> list = [];
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/admin/changes');
      list = ((r['changes'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _decide(Map<String, dynamic> c, bool ok) async {
    String reason = '';
    if (!ok) {
      final ctl = TextEditingController();
      final r = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('Why not?')),
          content: TextField(controller: ctl, decoration: field(t('e.g. Photo is not of the shop'))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(t('Send')))],
        ),
      );
      if (r == null) return;
      reason = r;
    }
    setState(() => busy = true);
    try {
      await api.call('POST', '/v1/admin/changes/${c['id']}/${ok ? 'approve' : 'reject'}', {'reason': reason});
      if (mounted) toast(context, ok ? t('Approved. The partner must sign the updated agreement.') : t('Sent back.'));
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _row(String k, String was, String now) {
    final changed = was != now;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: tx(11.5, color: kMute, weight: FontWeight.w700)),
        if (changed) Text(was, style: tx(13, color: kMute).copyWith(decoration: TextDecoration.lineThrough)),
        Text(now, style: tx(13.5, weight: changed ? FontWeight.w800 : FontWeight.w500)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Detail changes')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(child: Text(t('Nothing to check.'), style: tx(14, color: kMute)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final c in list)
                    Box(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _row(t('Name'), '${c['current']['name']}', '${c['next']['name']}'),
                        _row(t('Address'), '${c['current']['address']}', '${c['next']['address']}'),
                        if (c['kind'] != 'thela') ...[
                          _row('FSSAI', '${c['current']['fssai'] ?? ''}'.isEmpty ? '—' : '${c['current']['fssai']}', '${c['next']['fssai'] ?? ''}'.isEmpty ? '—' : '${c['next']['fssai']}'),
                          _row('GSTIN', '${c['current']['gstin'] ?? ''}'.isEmpty ? '—' : '${c['current']['gstin']}', '${c['next']['gstin'] ?? ''}'.isEmpty ? '—' : '${c['next']['gstin']}'),
                          _row('PAN', '${c['current']['pan'] ?? ''}'.isEmpty ? '—' : '${c['current']['pan']}', '${c['next']['pan'] ?? ''}'.isEmpty ? '—' : '${c['next']['pan']}'),
                        ],
                        Text(t('Documents'), style: tx(11.5, color: kMute, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        AdminDocList(
                          docs: ((c['docs'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                          missing: ((c['missingDocs'] as List?) ?? []).map((e) => '$e').toList(),
                        ),
                        const SizedBox(height: 8),
                        if (c['hasPhoto'] == true) ...[
                          Text(t('New photo'), style: tx(11.5, color: kMute, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network('$apiBase/v1/admin/changes/${c['id']}/photo',
                                headers: {'authorization': 'Bearer ${api.token}'}, height: 180, width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(children: [
                          Expanded(child: Btn(t('Approve'), onTap: busy || ((c['missingDocs'] as List?) ?? []).isNotEmpty ? null : () => _decide(c, true))),
                          const SizedBox(width: 10),
                          Expanded(child: Btn(t('Send back'), outline: true, color: kRed, onTap: busy ? null : () => _decide(c, false))),
                        ]),
                      ]),
                    ),
                ]),
    );
  }
}

/// Admin: every agreement a partner signed (newest first). Nothing is deleted.
Future<void> showAgreementVersions(BuildContext context, String storeId) async {
  List<Map<String, dynamic>> list = [];
  try {
    final r = await api.call('GET', '/v1/admin/partners/$storeId/agreements');
    list = ((r['agreements'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } on ApiError catch (e) {
    if (context.mounted) toast(context, e.message);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: kCard,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        Text(t('Agreement versions'), style: tx(17, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (list.isEmpty) Text(t('Not signed yet.'), style: tx(13, color: kMute)),
        for (final a in list)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: a['current'] == true ? kOkBg : kSurf, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['current'] == true ? t('Current') : t('Previous')} · v${a['version']} · ${a['signedDate']}', style: tx(13.5, weight: FontWeight.w800)),
              Text('${t('Signed by')} ${a['signerName']}', style: tx(12.5)),
              for (final k in const ['storeName', 'address', 'phone', 'fssai'])
                if ((((a['snapshot'] as Map?)?['vendor'] as Map?)?[k] ?? '').toString().isNotEmpty)
                  Text('${((a['snapshot'] as Map)['vendor'] as Map)[k]}', style: tx(12, color: kMute)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => openAgreementVersionPdf(ctx, a),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(t('Open signed PDF')),
              ),
            ]),
          ),
      ]),
    ),
  );
}

/// Admin: customers paused from "Call to my street" after 3 no-shows. Can be given back once in 90 days, with a reason.
class CallBlocksScreen extends StatefulWidget {
  const CallBlocksScreen({super.key});
  @override
  State<CallBlocksScreen> createState() => _CallBlocksScreenState();
}

class _CallBlocksScreenState extends State<CallBlocksScreen> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/admin/call-blocks');
      users = ((r['users'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _restore(Map<String, dynamic> u) async {
    final ctl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Give calling back?')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Only once in 90 days per customer. Their old no-shows stop counting.'), style: tx(12.5, color: kMute)),
          const SizedBox(height: 8),
          TextField(controller: ctl, maxLines: 2, decoration: field(t('Reason (at least 10 letters)'))),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(t('Give back')))],
      ),
    );
    if (reason == null) return;
    try {
      await api.call('POST', '/v1/admin/call-blocks/${u['id']}/restore', {'reason': reason});
      if (mounted) toast(context, t('Done. The customer is told.'));
      _load();
    } on ApiError catch (e) {
      if (mounted) {
        toast(context, switch (e.code) {
          'reason_needed' => t('Write a reason of at least 10 letters.'),
          'restored_recently' => t('Already given back in the last 90 days.'),
          _ => e.message,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Paused from calling thelas')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(child: Text(t('Nobody is paused.'), style: tx(14, color: kMute)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final u in users)
                    Box(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${u['name']}'.isEmpty ? '${u['email']}' : '${u['name']}', style: tx(14, weight: FontWeight.w800)),
                            Text('${u['phone']}'.isEmpty ? '${u['email']}' : '+91 ${u['phone']}', style: tx(12, color: kMute)),
                            Text(tr('{0} no-shows · paused till {1}', [u['strikes'], DateTime.fromMillisecondsSinceEpoch((u['until'] as num).toInt() * 1000).toString().substring(0, 10)]),
                                style: tx(12, color: kMute)),
                          ]),
                        ),
                        if (u['canRestore'] == true)
                          OutlinedButton(onPressed: () => _restore(u), child: Text(t('Give back')))
                        else
                          Text(t('Given back < 90 days'), style: tx(11.5, color: kMute)),
                      ]),
                    ),
                ]),
    );
  }
}
