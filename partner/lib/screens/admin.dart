import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../push.dart';
import 'changes_review.dart';
import '../session.dart';
import '../ui.dart';
import 'home.dart';
import 'review.dart';
import 'signature.dart';

/// Admin: where partners pay (UPI ID) and pass payments to check against the bank.
class AdminScreen extends StatefulWidget {
  /// Opened as the app's home (admin account without a shop).
  final bool root;
  const AdminScreen({super.key, this.root = false});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final upiId = TextEditingController();
  final upiName = TextEditingController();
  final party = {for (final k in ['legalName', 'address', 'city', 'pan', 'email']) k: TextEditingController()};
  List<Map<String, dynamic>> pays = [];
  bool all = false, _loading = true, _saving = false, testMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    upiId.dispose();
    upiName.dispose();
    for (final c in party.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await api.call('GET', '/v1/admin/settings');
      upiId.text = '${s['upiId'] ?? ''}';
      upiName.text = '${s['upiName'] ?? 'Nukad Kart'}';
      testMode = s['testMode'] == true;
      final pm = Map<String, dynamic>.from((s['party'] as Map?) ?? {});
      party.forEach((k, c) => c.text = '${pm[k] ?? ''}');
      sigB64 = '${pm['signature'] ?? ''}';
      sigName = '${pm['signName'] ?? ''}';
      await _loadPays();
      _loadHealth();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  bool morePays = false, _loadingMore = false;
  String sigB64 = '', sigName = '';
  Map<String, dynamic>? health;

  /// 20 at a time; "Load more" asks for the older ones.
  Future<void> _loadPays({bool more = false}) async {
    final q = <String>[if (all) 'status=ALL', if (more && pays.isNotEmpty) 'before=${pays.last['createdAt']}'];
    final r = await api.call('GET', '/v1/admin/payments${q.isEmpty ? '' : '?${q.join('&')}'}');
    final page = ((r['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    pays = more ? [...pays, ...page] : page;
    morePays = r['more'] == true;
    if (mounted) setState(() {});
  }

  String? _pushResult;
  bool _pushBusy = false;

  /// Sends a push to my own phone(s); shows exactly what the server got back.
  Future<void> _testPush() async {
    setState(() => _pushBusy = true);
    try {
      await setupPush(() {}); // make sure this phone's token is on the server
      final r = await api.call('POST', '/v1/admin/push-test');
      final errs = ((r['errors'] as List?) ?? []).join('\n');
      _pushResult = (r['sent'] ?? 0) > 0
          ? tr('Sent to {0} of {1} phones. It should appear in a few seconds.', [r['sent'], r['phones']])
          : '${tr('Not sent.')} $errs';
    } on ApiError catch (e) {
      _pushResult = e.message;
    }
    if (mounted) setState(() => _pushBusy = false);
  }

  Future<void> _loadHealth() async {
    try {
      health = await api.call('GET', '/v1/admin/health');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Widget _healthCard() {
    final h = health;
    if (h == null) return const SizedBox.shrink();
    String mb(num b) => b >= 1073741824
        ? '${(b / 1073741824).toStringAsFixed(2)} GB'
        : b >= 1048576
            ? '${(b / 1048576).toStringAsFixed(1)} MB'
            : '${(b / 1024).ceil()} KB';
    final used = ((h['dbBytes'] as num?) ?? 0) / ((h['dbLimitBytes'] as num?) ?? 1);
    Widget line(String k, String v, {bool ok = true}) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            Icon(ok ? Icons.check_circle : Icons.error_outline, size: 15, color: ok ? kAct : kAmb),
            const SizedBox(width: 6),
            Expanded(child: Text(k, style: tx(12.5, color: kMute))),
            Text(v, style: tx(12.5, weight: FontWeight.w700)),
          ]),
        );
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Server health'), style: tx(14.5, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: used.clamp(0.0, 1.0).toDouble(), minHeight: 8, color: used > 0.8 ? kRed : kAct, backgroundColor: kSurf),
        ),
        const SizedBox(height: 4),
        Text(tr('Database {0} of 5 GB · {1}', [mb((h['dbBytes'] as num?) ?? 0), h['dbServedBy']]), style: tx(11.5, color: kMute)),
        const SizedBox(height: 8),
        line(tr('Users'), '${h['users']}'),
        line(tr('Partners (approved)'), '${h['partners']} (${h['activePartners']})'),
        line(tr('Phones used in last 24 h'), '${h['activeToday']}'),
        line(tr('Documents'), '${h['docs']} · ${mb((h['docBytes'] as num?) ?? 0)}'),
        line(tr('Photos & documents in R2'), h['filesInR2'] == true ? tr('On') : tr('Off'), ok: h['filesInR2'] == true),
        line(tr('Push notifications'), h['pushReady'] == true ? tr('On · {0} phones', [h['pushPhones']]) : tr('Off'), ok: h['pushReady'] == true),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(_pushResult ?? tr('Send a test push to this phone to check notifications.'), style: tx(11.5, color: kMute))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _pushBusy ? null : _testPush, child: Text(_pushBusy ? '…' : tr('Send test'))),
        ]),
        const SizedBox(height: 4),
        Text(tr('Daily request and database limits: Cloudflare dashboard → Workers & Pages → nukad-kart-api → Metrics.'),
            style: tx(11, color: kMute)),
      ]),
    );
  }

  Future<void> _saveUpi() async {
    setState(() => _saving = true);
    try {
      await api.call('PUT', '/v1/admin/settings', {'upiId': upiId.text.trim(), 'upiName': upiName.text.trim()});
      if (mounted) toast(context, tr('UPI ID saved. New pass payments go here.'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setTestMode(bool on) async {
    setState(() => testMode = on);
    try {
      await api.call('PUT', '/v1/admin/settings', {'testMode': on});
      if (mounted) toast(context, on ? tr('Test mode on: every partner sees Demo pay') : tr('Test mode off'));
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => testMode = !on);
        toast(context, e.message);
      }
    }
  }

  Future<void> _saveParty() async {
    setState(() => _saving = true);
    try {
      await api.call('PUT', '/v1/admin/settings', {'party': party.map((k, c) => MapEntry(k, c.text.trim()))});
      if (mounted) toast(context, tr('Agreement details saved'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _decide(Map<String, dynamic> p, bool paid) async {
    String reason = '';
    if (!paid) {
      final c = TextEditingController(text: tr('Money not received in the bank'));
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Mark as not received?')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('{0} · ₹{1} · {2}\nThe pass days from this payment are removed and the partner is told.', [p['store'], p['amount'], p['id']])),
            const SizedBox(height: 10),
            TextField(controller: c, decoration: field(tr('Reason'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Back'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Not received'), style: TextStyle(color: kRed))),
          ],
        ),
      );
      if (ok != true) return;
      reason = c.text.trim();
    }
    try {
      await api.call('POST', '/v1/admin/payments/${p['id']}/${paid ? 'confirm' : 'cancel'}', paid ? {} : {'reason': reason});
      await _loadPays();
      if (mounted) toast(context, paid ? tr('Marked paid') : tr('Marked not received'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(tr('Admin'), actions: [
        if (widget.root)
          PopupMenuButton<String>(
            onSelected: (_) => session.signOut(),
            itemBuilder: (_) => [PopupMenuItem(value: 'out', child: Text(tr('Log out')))],
          ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPays,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (testMode) ...[
                  Box(
                    color: kRedBg,
                    border: kRedLine,
                    child: Text(tr('Test mode is ON · anyone can get a pass without paying. Turn it off before launch.'),
                        style: tx(12.5, color: kRed, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                ],
                Box(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Test mode'), style: tx(14.5, weight: FontWeight.w800)),
                        Text(tr('Shows "Demo pay" to all partners'), style: tx(12, color: kMute)),
                      ]),
                    ),
                    Switch(value: testMode, onChanged: _setTestMode),
                  ]),
                ),
                const SizedBox(height: 10),
                Btn(tr('Partners to verify'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnersScreen()))),
                const SizedBox(height: 10),
                Btn(tr('All partners · documents & agreements'), outline: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnersScreen(startAll: true)))),
                const SizedBox(height: 8),
                Btn(tr('Detail changes to check'), outline: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangesReviewScreen()))),
                const SizedBox(height: 8),
                Btn(tr('Paused from calling thelas'), outline: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallBlocksScreen()))),
                const SizedBox(height: 10),
                _healthCard(),
                const SizedBox(height: 18),
                Text(tr('Pass payments go to'), style: tx(15, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: upiId, decoration: field(tr('UPI ID, e.g. 98xxxxxx@okaxis'), label: tr('UPI ID'))),
                const SizedBox(height: 8),
                TextField(controller: upiName, decoration: field(tr('Name shown in the UPI app'), label: tr('Name'))),
                const SizedBox(height: 8),
                Btn(_saving ? tr('Saving…') : tr('Save UPI ID'), onTap: _saving ? null : _saveUpi),
                const SizedBox(height: 22),
                Text(tr('Agreement details (Nukad Kart side)'), style: tx(15, weight: FontWeight.w800)),
                Text(tr('Shown as the first party in every vendor agreement. Kept on the server, not in the app code.'),
                    style: tx(12, color: kMute)),
                const SizedBox(height: 8),
                TextField(controller: party['legalName'], decoration: field(tr('Proprietor’s full legal name'), label: tr('Legal name'))),
                const SizedBox(height: 8),
                TextField(controller: party['address'], maxLines: 2, decoration: field(tr('Complete business address'), label: tr('Address'))),
                const SizedBox(height: 8),
                TextField(controller: party['city'], decoration: field(tr('e.g. New Delhi, Delhi'), label: tr('Court city (jurisdiction)'))),
                const SizedBox(height: 8),
                TextField(controller: party['pan'], textCapitalization: TextCapitalization.characters, decoration: field('ABCDE1234F', label: 'PAN')),
                const SizedBox(height: 8),
                TextField(controller: party['email'], keyboardType: TextInputType.emailAddress, decoration: field(tr('Official email'), label: tr('Email'))),
                const SizedBox(height: 8),
                Btn(_saving ? tr('Saving…') : tr('Save agreement details'), outline: true, onTap: _saving ? null : _saveParty),
                const SizedBox(height: 10),
                Box(
                  child: Row(children: [
                    Container(
                      width: 90,
                      height: 50,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
                      child: sigB64.isEmpty ? Icon(Icons.draw_outlined, color: kMute) : Image.memory(base64Decode(sigB64), fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('Nukad Kart signature'), style: tx(14, weight: FontWeight.w800)),
                        Text(sigB64.isEmpty ? t('Not added yet: agreements show only the vendor’s sign') : sigName, style: tx(12, color: sigB64.isEmpty ? kAmb : kMute)),
                      ]),
                    ),
                    TextButton(
                      onPressed: () async {
                        final done = await Navigator.push<bool>(context,
                            MaterialPageRoute(builder: (_) => AdminSignatureScreen(name: sigName.isEmpty ? party['legalName']!.text : sigName, current: sigB64)));
                        if (done == true) _load();
                      },
                      child: Text(sigB64.isEmpty ? t('Add') : t('Change')),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: Text(all ? tr('All recent payments') : tr('Payments to check'), style: tx(15, weight: FontWeight.w800))),
                  TextButton(
                    onPressed: () {
                      all = !all;
                      _loadPays();
                    },
                    child: Text(all ? tr('Only to check') : tr('Show all')),
                  ),
                ]),
                Text(tr('Match each Payment ID with the UPI note in your bank / UPI app history.'), style: tx(12, color: kMute)),
                const SizedBox(height: 8),
                if (pays.isEmpty) Text(tr('Nothing to check right now.'), style: tx(13.5, color: kMute)),
                for (final p in pays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Box(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${p['store']}', style: tx(14.5, weight: FontWeight.w800))),
                          pill('${p['status']}', color: p['status'] == 'PAID' ? kAct : kAmb, bg: p['status'] == 'PAID' ? kOkBg : kAmbBg),
                        ]),
                        Text('${p['planName']} · ₹${p['amount']} · ${p['id']}', style: tx(13)),
                        Text(tr('{0} · UPI app said: {1}{2}', [dateText((p['createdAt'] as num).toInt()), p['upiStatus'] ?? 'nothing', p['upiRef'] != null ? ' · ref ${p['upiRef']}' : '']),
                            style: tx(11.5, color: kMute)),
                        if (p['needsCheck'] == true) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _decide(p, true),
                                style: FilledButton.styleFrom(backgroundColor: kAct),
                                child: Text(p['status'] == 'PAID' ? tr('Money is in ✓') : tr('Paid · start pass')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _decide(p, false),
                                style: OutlinedButton.styleFrom(foregroundColor: kRed, side: BorderSide(color: kRed)),
                                child: Text(tr('Not received')),
                              ),
                            ),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                if (morePays)
                  TextButton(
                    onPressed: _loadingMore
                        ? null
                        : () async {
                            setState(() => _loadingMore = true);
                            try {
                              await _loadPays(more: true);
                            } on ApiError catch (e) {
                              if (context.mounted) toast(context, e.message);
                            }
                            if (mounted) setState(() => _loadingMore = false);
                          },
                    child: Text(_loadingMore ? tr('Loading…') : tr('Load more')),
                  ),
              ]),
            ),
    );
  }
}
