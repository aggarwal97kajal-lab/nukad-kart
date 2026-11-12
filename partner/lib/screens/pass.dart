import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import '../upi.dart';
import 'home.dart';
import 'pass_active.dart';

class PassScreen extends StatefulWidget {
  const PassScreen({super.key});
  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  List<Map<String, dynamic>> plans = [];
  String upiId = '', upiName = 'Nukad Kart';
  String selected = 'monthly';
  bool _loading = true;
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
      testMode = r['testMode'] == true;
      _error = null;
    } on ApiError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> get _plan => plans.firstWhere((p) => p['id'] == selected, orElse: () => plans.first);

  bool testMode = false;

  void _pay() {
    if (upiId.isEmpty && !(testMode || session.admin)) {
      toast(context, const ApiError(503, 'upi_not_set').message);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PayScreen(plan: _plan, upiReady: upiId.isNotEmpty, demo: testMode || session.admin)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(tr('Choose your pass')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: tx(14)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text(tr('Your shop shows to customers within 500 m only while a pass is active. No commission on orders.'),
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
                            color: selected == p['id'] ? kSurf : kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected == p['id'] ? kAct : kLine, width: selected == p['id'] ? 2 : 1),
                          ),
                          child: Row(children: [
                            Icon(selected == p['id'] ? Icons.radio_button_checked : Icons.radio_button_off, color: kAct),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(t('${p['name']}'), style: tx(16, weight: FontWeight.w800)),
                                  if (p['id'] == 'monthly') ...[const SizedBox(width: 8), pill('POPULAR')],
                                ]),
                                Text(p['days'] == 1 ? t('1 day') : tr('{0} days', [p['days']]), style: tx(12, color: kMute)),
                              ]),
                            ),
                            Text('₹${p['price']}', style: tx(20, weight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(tr('🔒 Pay with any UPI app on this phone. A new pass starts when the current one ends.'),
                      style: tx(11.5, color: kMute)),
                  const SizedBox(height: 16),
                  Btn(tr('Pay ₹{0} with UPI', [_plan['price']]), onTap: _pay),
                ]),
    );
  }
}

/// Nukad Kart's own payment page: the UPI apps on this phone (real names and icons from the phone).
class PayScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final bool upiReady, demo;
  const PayScreen({super.key, required this.plan, required this.upiReady, required this.demo});
  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  List<UpiApp>? apps;
  String? _busy; // package being opened, or 'demo'

  @override
  void initState() {
    super.initState();
    installedUpiApps().then((a) {
      if (mounted) setState(() => apps = _sorted(a));
    });
  }

  /// Most-used UPI apps first, then the rest A–Z.
  static List<UpiApp> _sorted(List<UpiApp> a) {
    const first = ['com.google.android.apps.nbu.paisa.user', 'com.phonepe.app', 'net.one97.paytm', 'in.org.npci.upiapp'];
    int rank(UpiApp x) {
      final i = first.indexOf(x.package);
      return i < 0 ? first.length : i;
    }

    return [...a]..sort((x, y) {
        final r = rank(x).compareTo(rank(y));
        return r != 0 ? r : x.name.toLowerCase().compareTo(y.name.toLowerCase());
      });
  }

  Future<void> _payWith(UpiApp app) async {
    setState(() => _busy = app.package);
    final key = newPaymentKey();
    try {
      final c = await api.call('POST', '/v1/partner/payments', {'plan': widget.plan['id'], 'key': key});
      final pay = Map<String, dynamic>.from(c['payment'] as Map);
      final answer = await payWithUpi(
        upiId: '${c['upiId']}',
        name: '${c['upiName']}',
        amount: (pay['amount'] as num),
        note: 'Nukad Kart ${pay['planName']} pass ${pay['id']}',
        ref: '${pay['id']}',
        package: app.package,
      );
      final d = await api.call('POST', '/v1/partner/payments/$key/done', {'upiStatus': answer.status, 'upiRef': answer.ref, 'app': app.name});
      if (d['store'] is Map) session.setStore(Map<String, dynamic>.from(d['store'] as Map));
      session.refresh().catchError((_) {});
      if (!mounted) return;
      _done('${(d['payment'] as Map)['status']}', Map<String, dynamic>.from(d['payment'] as Map));
      return;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, tr('Could not open {0}. Try another app.', [app.name]));
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _demoPay() async {
    setState(() => _busy = 'demo');
    try {
      final r = await api.call('POST', '/v1/partner/payments', {'plan': widget.plan['id'], 'key': newPaymentKey(), 'demo': true});
      if (r['store'] is Map) session.setStore(Map<String, dynamic>.from(r['store'] as Map));
      session.refresh().catchError((_) {});
      if (!mounted) return;
      _done('PAID', Map<String, dynamic>.from(r['payment'] as Map));
      return;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = null);
  }

  void _done(String status, Map<String, dynamic> payment) {
    final nav = Navigator.of(context);
    nav.pop(); // this page
    nav.pushReplacement(MaterialPageRoute(builder: (_) => PayResultScreen(status: status, payment: payment)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final st = session.store ?? {};
    final startsLater = st['passActive'] == true;
    return Scaffold(
      appBar: bar(tr('Pay for your pass')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Box(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('{0} pass', [t('${p['name']}')]), style: tx(16, weight: FontWeight.w800)),
                Text(tr('{0} day{1} · {2}', [p['days'], p['days'] == 1 ? '' : 's', startsLater ? 'starts when your current pass ends' : 'starts now']),
                    style: tx(12, color: kMute)),
                const SizedBox(height: 4),
                Text(tr('To: Nukad Kart'), style: tx(12, color: kMute)),
              ]),
            ),
            Text('₹${p['price']}', style: tx(24, weight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(tr('Pay with an app on this phone'), style: tx(14, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (!widget.upiReady)
          Box(color: kAmbBg, child: Text(tr('UPI payments are not open yet. Try again later.'), style: tx(13)))
        else if (apps == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (apps!.isEmpty)
          Box(
              child: Text(tr('No UPI app found on this phone. Install Google Pay, PhonePe, Paytm, BHIM or your bank’s UPI app.'),
                  style: tx(13.5)))
        else
          Container(
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
            child: Column(children: [
              for (var i = 0; i < apps!.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 68),
                ListTile(
                  enabled: _busy == null,
                  onTap: () => _payWith(apps![i]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: apps![i].icon == null
                        ? Container(width: 40, height: 40, color: kSurf, child: Icon(Icons.account_balance_wallet_outlined, color: kAct))
                        : Image.memory(apps![i].icon!, width: 40, height: 40, filterQuality: FilterQuality.medium),
                  ),
                  title: Text(apps![i].name, style: tx(15, weight: FontWeight.w700)),
                  trailing: _busy == apps![i].package
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Icon(Icons.chevron_right, color: kMute),
                ),
              ],
            ]),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.lock_outline, size: 15, color: kMute),
          const SizedBox(width: 6),
          Expanded(child: Text(tr('Tap an app: it opens with ₹{0} filled in. Come back here after paying.', [p['price']]), style: tx(11.5, color: kMute))),
        ]),
        if (widget.demo) ...[
          const SizedBox(height: 16),
          Box(
            color: kAmbBg,
            border: kAmbLine,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              pill(tr('TEST MODE'), color: kAmb, bg: kAmbLine),
              const SizedBox(height: 6),
              Text(tr('Start this pass without paying. It is marked DEMO and the admin can remove it.'), style: tx(12.5)),
              const SizedBox(height: 8),
              Btn(_busy == 'demo' ? tr('Starting…') : tr('Demo pay ₹{0}', [p['price']]), outline: true, color: kAmb, onTap: _busy != null ? null : _demoPay),
            ]),
          ),
        ],
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
    if (status == 'PAID') return PassActiveScreen(payment: payment);
    final (icon, title, body, color) = switch (status) {
      'PAID' => (Icons.check_circle, tr('Pass active'), tr('Your {0} pass is on. Switch LIVE on to show your shop.', [payment['planName']]), kAct),
      'FAILED' => (Icons.cancel, tr('Payment failed'), tr('No money was taken for the pass. Try again or use another UPI app.'), kRed),
      _ => (
          Icons.hourglass_top,
          tr('Checking your payment…'),
          tr('We haven’t got the confirmation for ₹{0} yet. If money left your account, don’t pay again: our team has been told and the pass starts as soon as it is confirmed.', [payment['amount']]),
          kAmb
        ),
    };
    return Scaffold(
      appBar: bar(tr('Payment')),
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
          Text(tr('Payment ID {0} · {1}', [payment['id'], dateText((payment['createdAt'] as num).toInt())]), style: tx(12, color: kMute)),
          const Spacer(),
          Btn(tr('Done'), onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}
