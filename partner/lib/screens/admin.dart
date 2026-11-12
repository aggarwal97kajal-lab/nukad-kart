import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import 'home.dart';
import 'review.dart';

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
      await _loadPays();
      _loadHealth();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  bool morePays = false, _loadingMore = false;
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

  Future<void> _loadHealth() async {
    try {
      health = await api.call('GET', '/v1/admin/health');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Widget _healthCard() {
    final h = health;
    if (h == null) return const SizedBox.shrink();
    String mb(num b) => b >= 1024 * 1024 * 1024 ? '${(b / 1073741824).toStringAsFixed(2)} GB' : '${(b / 1048576).toStringAsFixed(1)} MB';
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
        Text('Server health', style: tx(14.5, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: used.clamp(0.0, 1.0).toDouble(), minHeight: 8, color: used > 0.8 ? kRed : kAct, backgroundColor: kSurf),
        ),
        const SizedBox(height: 4),
        Text('Database ${mb((h['dbBytes'] as num?) ?? 0)} of 5 GB · ${h['dbServedBy']}', style: tx(11.5, color: kMute)),
        const SizedBox(height: 8),
        line('Users', '${h['users']}'),
        line('Partners (approved)', '${h['partners']} (${h['activePartners']})'),
        line('Phones used in last 24 h', '${h['activeToday']}'),
        line('Documents', '${h['docs']} · ${mb((h['docBytes'] as num?) ?? 0)}'),
        line('Photos & documents in R2', h['filesInR2'] == true ? 'On' : 'Off', ok: h['filesInR2'] == true),
        line('Push notifications', h['pushReady'] == true ? 'On · ${h['pushPhones']} phones' : 'Off', ok: h['pushReady'] == true),
        const SizedBox(height: 4),
        Text('Daily request and database limits: Cloudflare dashboard → Workers & Pages → nukad-kart-api → Metrics.',
            style: tx(11, color: kMute)),
      ]),
    );
  }

  Future<void> _saveUpi() async {
    setState(() => _saving = true);
    try {
      await api.call('PUT', '/v1/admin/settings', {'upiId': upiId.text.trim(), 'upiName': upiName.text.trim()});
      if (mounted) toast(context, 'UPI ID saved. New pass payments go here.');
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setTestMode(bool on) async {
    setState(() => testMode = on);
    try {
      await api.call('PUT', '/v1/admin/settings', {'testMode': on});
      if (mounted) toast(context, on ? 'Test mode on: every partner sees Demo pay' : 'Test mode off');
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
      if (mounted) toast(context, 'Agreement details saved');
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _decide(Map<String, dynamic> p, bool paid) async {
    String reason = '';
    if (!paid) {
      final c = TextEditingController(text: 'Money not received in the bank');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mark as not received?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${p['store']} · ₹${p['amount']} · ${p['id']}\nThe pass days from this payment are removed and the partner is told.'),
            const SizedBox(height: 10),
            TextField(controller: c, decoration: field('Reason')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Not received', style: TextStyle(color: kRed))),
          ],
        ),
      );
      if (ok != true) return;
      reason = c.text.trim();
    }
    try {
      await api.call('POST', '/v1/admin/payments/${p['id']}/${paid ? 'confirm' : 'cancel'}', paid ? {} : {'reason': reason});
      await _loadPays();
      if (mounted) toast(context, paid ? 'Marked paid' : 'Marked not received');
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('Admin', actions: [
        if (widget.root)
          PopupMenuButton<String>(
            onSelected: (_) => session.signOut(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'out', child: Text('Log out'))],
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
                    border: const Color(0xFFF7C1C1),
                    child: Text('Test mode is ON · anyone can get a pass without paying. Turn it off before launch.',
                        style: tx(12.5, color: kRed, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                ],
                Box(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Test mode', style: tx(14.5, weight: FontWeight.w800)),
                        Text('Shows "Demo pay" to all partners', style: tx(12, color: kMute)),
                      ]),
                    ),
                    Switch(value: testMode, activeThumbColor: kBrand, activeTrackColor: kAct, onChanged: _setTestMode),
                  ]),
                ),
                const SizedBox(height: 10),
                Btn('Partners to verify', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnersScreen()))),
                const SizedBox(height: 10),
                _healthCard(),
                const SizedBox(height: 18),
                Text('Pass payments go to', style: tx(15, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: upiId, decoration: field('UPI ID, e.g. 98xxxxxx@okaxis', label: 'UPI ID')),
                const SizedBox(height: 8),
                TextField(controller: upiName, decoration: field('Name shown in the UPI app', label: 'Name')),
                const SizedBox(height: 8),
                Btn(_saving ? 'Saving…' : 'Save UPI ID', onTap: _saving ? null : _saveUpi),
                const SizedBox(height: 22),
                Text('Agreement details (Nukad Kart side)', style: tx(15, weight: FontWeight.w800)),
                Text('Shown as the first party in every vendor agreement. Kept on the server, not in the app code.',
                    style: tx(12, color: kMute)),
                const SizedBox(height: 8),
                TextField(controller: party['legalName'], decoration: field('Proprietor’s full legal name', label: 'Legal name')),
                const SizedBox(height: 8),
                TextField(controller: party['address'], maxLines: 2, decoration: field('Complete business address', label: 'Address')),
                const SizedBox(height: 8),
                TextField(controller: party['city'], decoration: field('e.g. New Delhi, Delhi', label: 'Court city (jurisdiction)')),
                const SizedBox(height: 8),
                TextField(controller: party['pan'], textCapitalization: TextCapitalization.characters, decoration: field('ABCDE1234F', label: 'PAN')),
                const SizedBox(height: 8),
                TextField(controller: party['email'], keyboardType: TextInputType.emailAddress, decoration: field('Official email', label: 'Email')),
                const SizedBox(height: 8),
                Btn(_saving ? 'Saving…' : 'Save agreement details', outline: true, onTap: _saving ? null : _saveParty),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: Text(all ? 'All recent payments' : 'Payments to check', style: tx(15, weight: FontWeight.w800))),
                  TextButton(
                    onPressed: () {
                      all = !all;
                      _loadPays();
                    },
                    child: Text(all ? 'Only to check' : 'Show all'),
                  ),
                ]),
                Text('Match each Payment ID with the UPI note in your bank / UPI app history.', style: tx(12, color: kMute)),
                const SizedBox(height: 8),
                if (pays.isEmpty) Text('Nothing to check right now.', style: tx(13.5, color: kMute)),
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
                        Text('${dateText((p['createdAt'] as num).toInt())} · UPI app said: ${p['upiStatus'] ?? 'nothing'}${p['upiRef'] != null ? ' · ref ${p['upiRef']}' : ''}',
                            style: tx(11.5, color: kMute)),
                        if (p['needsCheck'] == true) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _decide(p, true),
                                style: FilledButton.styleFrom(backgroundColor: kAct),
                                child: Text(p['status'] == 'PAID' ? 'Money is in ✓' : 'Paid · start pass'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _decide(p, false),
                                style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
                                child: const Text('Not received'),
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
                    child: Text(_loadingMore ? 'Loading…' : 'Load more'),
                  ),
              ]),
            ),
    );
  }
}
