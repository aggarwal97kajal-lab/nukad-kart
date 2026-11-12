import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';

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
                          Expanded(child: Btn(t('Approve'), onTap: busy ? null : () => _decide(c, true))),
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
              for (final k in const ['name', 'address', 'phone'])
                if (((a['snapshot'] as Map?)?[k] ?? '').toString().isNotEmpty) Text('${(a['snapshot'] as Map)[k]}', style: tx(12, color: kMute)),
            ]),
          ),
      ]),
    ),
  );
}
