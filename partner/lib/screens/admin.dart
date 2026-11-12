import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'home.dart';

/// Admin: where partners pay (UPI ID) and pass payments to check against the bank.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final upiId = TextEditingController();
  final upiName = TextEditingController();
  final party = {for (final k in ['legalName', 'address', 'city', 'pan', 'email']) k: TextEditingController()};
  List<Map<String, dynamic>> pays = [];
  bool all = false, _loading = true, _saving = false;

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
      final pm = Map<String, dynamic>.from((s['party'] as Map?) ?? {});
      party.forEach((k, c) => c.text = '${pm[k] ?? ''}');
      await _loadPays();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPays() async {
    final r = await api.call('GET', '/v1/admin/payments${all ? '?status=ALL' : ''}');
    pays = ((r['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (mounted) setState(() {});
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
      appBar: bar('Admin'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPays,
              child: ListView(padding: const EdgeInsets.all(16), children: [
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
              ]),
            ),
    );
  }
}
