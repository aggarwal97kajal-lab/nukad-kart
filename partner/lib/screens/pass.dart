import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import '../upi.dart';
import 'home.dart';

class PassScreen extends StatefulWidget {
  const PassScreen({super.key});
  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  List<Map<String, dynamic>> plans = [];
  String upiId = '', upiName = 'Nukad Kart';
  String selected = 'monthly';
  bool _loading = true, _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/plans');
      plans = ((r['plans'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      upiId = '${r['upiId'] ?? ''}';
      upiName = '${r['upiName'] ?? 'Nukad Kart'}';
      _error = null;
    } on ApiError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> get _plan => plans.firstWhere((p) => p['id'] == selected, orElse: () => plans.first);

  Future<UpiApp?> _pickApp() async {
    final apps = await installedUpiApps();
    if (!mounted) return null;
    return showModalBottomSheet<UpiApp?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Pay ₹${_plan['price']} using', style: tx(18, weight: FontWeight.w800)),
          ),
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No UPI app found on this phone. Install Google Pay, PhonePe, Paytm or your bank’s UPI app.',
                  style: tx(13.5)),
            ),
          for (final a in apps)
            ListTile(
              leading: a.icon == null
                  ? const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined))
                  : Image.memory(a.icon!, width: 40, height: 40),
              title: Text(a.name, style: tx(15, weight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, a),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pay() async {
    if (upiId.isEmpty) {
      toast(context, const ApiError(503, 'upi_not_set').message);
      return;
    }
    final app = await _pickApp();
    if (app == null || !mounted) return;
    setState(() => _paying = true);
    final key = newPaymentKey();
    try {
      final c = await api.call('POST', '/v1/partner/payments', {'plan': selected, 'key': key});
      final pay = Map<String, dynamic>.from(c['payment'] as Map);
      final answer = await payWithUpi(
        upiId: '${c['upiId']}',
        name: '${c['upiName']}',
        amount: (pay['amount'] as num),
        note: 'Nukad Kart ${pay['planName']} pass ${pay['id']}',
        ref: '${pay['id']}',
        package: app.package,
      );
      final d = await api.call('POST', '/v1/partner/payments/$key/done',
          {'upiStatus': answer.status, 'upiRef': answer.ref, 'app': app.name});
      await session.refresh();
      if (!mounted) return;
      final status = (d['payment'] as Map)['status'];
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PayResultScreen(status: '$status', payment: Map<String, dynamic>.from(d['payment'] as Map))));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'Could not open the UPI app. Try another app.');
    }
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('Choose your pass'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: tx(14)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Your shop shows to customers within 500 m only while a pass is active. No commission on orders.',
                      style: tx(13, color: kMute)),
                  const SizedBox(height: 12),
                  for (final p in plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => selected = '${p['id']}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected == p['id'] ? kSurf : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected == p['id'] ? kAct : kLine, width: selected == p['id'] ? 2 : 1),
                          ),
                          child: Row(children: [
                            Icon(selected == p['id'] ? Icons.radio_button_checked : Icons.radio_button_off, color: kAct),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('${p['name']}', style: tx(16, weight: FontWeight.w800)),
                                  if (p['id'] == 'monthly') ...[const SizedBox(width: 8), pill('POPULAR')],
                                ]),
                                Text('${p['days']} day${p['days'] == 1 ? '' : 's'}', style: tx(12, color: kMute)),
                              ]),
                            ),
                            Text('₹${p['price']}', style: tx(20, weight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text('🔒 Pay with any UPI app on this phone. A new pass starts when the current one ends.',
                      style: tx(11.5, color: kMute)),
                  const SizedBox(height: 16),
                  Btn(_paying ? 'Opening UPI app…' : 'Pay ₹${_plan['price']} with UPI', onTap: _paying ? null : _pay),
                ]),
    );
  }
}

class PayResultScreen extends StatelessWidget {
  final String status;
  final Map<String, dynamic> payment;
  const PayResultScreen({super.key, required this.status, required this.payment});

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, color) = switch (status) {
      'PAID' => (Icons.check_circle, 'Pass active', 'Your ${payment['planName']} pass is on. Switch LIVE on to show your shop.', kAct),
      'FAILED' => (Icons.cancel, 'Payment failed', 'No money was taken for the pass. Try again or use another UPI app.', kRed),
      _ => (
          Icons.hourglass_top,
          'Checking your payment…',
          'We haven’t got the confirmation for ₹${payment['amount']} yet. If money left your account, don’t pay again: our team has been told and the pass starts as soon as it is confirmed.',
          kAmb
        ),
    };
    return Scaffold(
      appBar: bar('Payment'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 30),
          Icon(icon, color: color, size: 84),
          const SizedBox(height: 14),
          Text(title, style: tx(22, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: tx(14, color: kMute)),
          const SizedBox(height: 10),
          Text('Payment ID ${payment['id']} · ${dateText((payment['createdAt'] as num).toInt())}', style: tx(12, color: kMute)),
          const Spacer(),
          Btn('Done', onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}
