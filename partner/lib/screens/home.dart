import 'dart:async';
import 'package:flutter/material.dart';
import 'shell.dart';
import 'live_setup.dart';
import 'calls_card.dart';
import 'chats.dart';
import 'staff.dart';
import '../thela_location.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import 'pass.dart';
import 'admin.dart';
import 'agreement.dart';
import 'delete.dart';
import 'docs.dart';
import 'register.dart';

String dateText(int secs) {
  final d = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  // ignore: i18n
  const m = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${m[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    try {
      await session.refresh();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  bool _liveBusy = false;

  /// The switch moves at once; the server confirms in the background (and it flips back if the server says no).
  Future<void> _setLive(bool on) async {
    if (_liveBusy) return;
    // A thela is seen on the map only while its location comes in: set the phone up first.
    if (on && session.store?['kind'] == 'thela' && !await ThelaLocation.ready()) {
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LiveSetupScreen()));
      if (ok != true || !mounted) return;
    }
    final before = Map<String, dynamic>.from(session.store!);
    _liveBusy = true;
    session.setStore({...before, 'live': on, 'offlineReason': on ? null : 'switched_off'});
    try {
      final r = await api.call('POST', '/v1/partner/live', {'on': on});
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
    } on ApiError catch (e) {
      session.setStore(before);
      if (mounted) toast(context, e.message);
    }
    _liveBusy = false;
    ThelaLocation.instance.sync();
  }

  Future<void> _resubmit() async {
    setState(() => _busy = true);
    try {
      final r = await api.call('POST', '/v1/partner/submit');
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
      if (mounted) toast(context, tr('Sent. Nukad team will check again.'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  (String, String, Color, Color) _status(Map<String, dynamic> s) {
    final reason = s['offlineReason'];
    return switch (reason) {
      null => (tr('You are LIVE'), tr('Customers within 500 m can see you and order.'), kOnAct, kAct),
      'no_pass' => (tr('Pass ended · hidden'), tr('Customers can’t see you. Buy a pass to go live.'), kRed, kRedBg),
      'blocked' => (tr('Account blocked'), tr('Contact Nukad Kart support.'), kRed, kRedBg),
      'closed_now' => (tr('Closed now'), tr('Outside your timings ({0} – {1}). You show again at opening time.', [s['opensAt'], s['closesAt']]), kAmb, kAmbBg),
      'missed_orders' => (tr('Offline for today'), tr('5 orders were missed today. Switch on to go live again.'), kAmb, kAmbBg),
      'no_agreement' => (tr('Agreement not signed'), tr('Sign the partner agreement to go live.'), kRed, kRedBg),
      'not_verified' => (tr('Waiting for verification'), tr('Nukad team is verifying your details and documents. Your shop can go live after approval.'), kAmb, kAmbBg),
      'rejected' => (tr('Changes needed'), tr('Nukad team asked for changes. Fix them below and send again.'), kRed, kRedBg),
      _ => (tr('You are offline'), tr('Switch on to show your shop to customers.'), kInk, kSurf),
    };
  }

  Future<void> _confirmPrices() async {
    try {
      final r = await api.call('POST', '/v1/partner/products/confirm-prices');
      session.setStore({...?session.store, 'pricesConfirmed': r['pricesConfirmed']});
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session.store!;
        final (title, sub, fg, bg) = _status(s);
        final passActive = s['passActive'] == true;
        final passUntil = (s['passUntil'] as num?)?.toInt() ?? 0;
        final daysLeft = passActive ? ((passUntil - DateTime.now().millisecondsSinceEpoch ~/ 1000) / 86400).ceil() : 0;
        return Scaffold(
          appBar: bar('${s['name']}', actions: [
            if (session.admin)
              IconButton(
                tooltip: tr('Admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'out') session.signOut();
                if (v == 'staff') Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen()));
                if (v == 'delete') Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
                if (v == 'agreement') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AgreementScreen(viewOnly: true)));
                }
              },
              itemBuilder: (_) => [
                if (s['kind'] != 'thela') PopupMenuItem(value: 'staff', child: Text(tr('Staff'))),
                PopupMenuItem(value: 'agreement', child: Text(tr('Partner agreement'))),
                PopupMenuItem(value: 'out', child: Text(tr('Log out'))),
                PopupMenuItem(value: 'delete', child: Text(tr('Delete account'), style: TextStyle(color: kRed))),
              ],
            ),
          ]),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: s['offlineReason'] == null ? kAct : bg, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: tx(18, color: s['offlineReason'] == null ? kOnAct : fg, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sub, style: tx(12.5, color: s['offlineReason'] == null ? kOnAct : kInk)),
                    ]),
                  ),
                  Switch(
                    value: s['live'] == true,
                    // The LIVE card is filled with the action colour, so the ON switch uses the opposite colours to stay visible.
                    activeTrackColor: kOnAct,
                    trackOutlineColor: WidgetStateProperty.all(s['live'] == true ? kOnAct : null),
                    thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? kAct : null),
                    thumbIcon: WidgetStateProperty.resolveWith(
                        (st) => st.contains(WidgetState.selected) ? Icon(Icons.check, size: 16, color: kOnAct) : null),
                    onChanged: (s['live'] != true && (!passActive || s['status'] != 'active')) ? null : _setLive,
                  ),
                ]),
              ),
              if (s['kind'] == 'thela' && s['live'] == true) ...[
                const SizedBox(height: 8),
                _LocationStatus(),
                const CallsCard(),
              ],
              if (s['kind'] == 'thela') const ChatsCard(),
              if (s['kind'] == 'thela' && session.selling > 0 && s['pricesConfirmed'] != s['today']) ...[
                const SizedBox(height: 12),
                Box(
                  color: kSurf,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('Same prices as yesterday?'), style: tx(15, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(tr('You are selling {0} items. Customers see these prices.', [session.selling]), style: tx(12.5, color: kMute)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Btn(t('Yes, same'), onTap: _confirmPrices)),
                      const SizedBox(width: 10),
                      Expanded(child: Btn(t('Change'), outline: true, onTap: () => shellTab.value = 1)),
                    ]),
                  ]),
                ),
              ],
              if (s['status'] == 'review') ...[
                const SizedBox(height: 12),
                Box(
                  color: kSurf,
                  child: Row(children: [
                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kAmb)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          tr('Nukad team is verifying your shop. This usually takes less than a day. Pull down to check. ') +
                              (session.trialAvailable
                                  ? t('Your 7-day free trial starts when you are approved.')
                                  : t('Free trial was already used on this number or phone.')),
                          style: tx(12.5, weight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
              if (s['status'] == 'rejected') ...[
                const SizedBox(height: 12),
                Box(
                  color: kRedBg,
                  border: kRedLine,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('What to fix'), style: tx(14, color: kRed, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${s['reviewNote'] ?? ''}', style: tx(13.5)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              child: Text(tr('Edit details')))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocsScreen(pushed: true))),
                              child: Text(tr('Documents')))),
                    ]),
                    const SizedBox(height: 8),
                    Btn(_busy ? tr('Sending…') : tr('Send for verification again'), onTap: _busy ? null : _resubmit),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Box(
                child: Row(children: [
                  Icon(Icons.confirmation_number_outlined, color: kAct, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(passActive ? tr('{0} · {1} day{2} left', [s['trial'] == true ? 'Free trial' : 'Pass active', daysLeft, daysLeft == 1 ? '' : 's']) : tr('No active pass'),
                          style: tx(15, weight: FontWeight.w800)),
                      Text(passActive ? tr('Ends {0}', [dateText(passUntil)]) : tr('Your shop shows to customers only with a pass.'),
                          style: tx(12.5, color: kMute)),
                    ]),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassScreen())),
                    style: FilledButton.styleFrom(backgroundColor: kAct),
                    child: Text(passActive ? tr('Extend') : tr('Buy pass')),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Today'), style: tx(15, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(tr('Missed orders: {0} of 5', [s['missedToday'] ?? 0]), style: tx(13)),
                  Text(tr('Orders arrive here soon. A new order rings until you accept it (5 minutes).'), style: tx(12, color: kMute)),
                ]),
              ),
              if (session.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('Pass payments'), style: tx(15, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final p in session.payments) PaymentRow(p),
              ],
              const SizedBox(height: 16),
              Text('${s['address'] ?? ''}', style: tx(12, color: kMute)),
            ]),
          ),
        );
      },
    );
  }
}

class PaymentRow extends StatelessWidget {
  final Map<String, dynamic> p;
  const PaymentRow(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (p['status']) {
      'PAID' => (tr('Paid'), kAct, kOkBg),
      'CHECKING' => (tr('Being checked'), kAmb, kAmbBg),
      'FAILED' => (tr('Failed'), kRed, kRedBg),
      'CANCELLED' => (tr('Not received'), kRed, kRedBg),
      _ => (tr('Not finished'), kMute, kSurf),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['planName']} · ₹${p['amount']}', style: tx(14, weight: FontWeight.w700)),
              Text('${p['id']} · ${dateText((p['createdAt'] as num).toInt())}', style: tx(11.5, color: kMute)),
              if ((p['reason'] ?? '').toString().isNotEmpty) Text('${p['reason']}', style: tx(11.5, color: kRed)),
            ]),
          ),
          pill(label, color: fg, bg: bg),
        ]),
      ),
    );
  }
}

/// "Location sent 20 s ago" — shows a LIVE thela that customers can see it.
class _LocationStatus extends StatefulWidget {
  @override
  State<_LocationStatus> createState() => _LocationStatusState();
}

class _LocationStatusState extends State<_LocationStatus> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ThelaLocation.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([loc.lastOk, loc.lastError]),
      builder: (context, _) {
        final at = loc.lastOk.value;
        final ago = at == null ? null : DateTime.now().difference(at).inSeconds;
        final ok = ago != null && ago < 180;
        final text = at == null
            ? (loc.lastError.value != null ? tr('Location not sent: {0}', [loc.lastError.value]) : t('Sending your location…'))
            : ago! < 60
                ? tr('Location sent {0} s ago · customers see you', [ago])
                : tr('Location sent {0} min ago', [ago ~/ 60]);
        return Row(children: [
          Icon(ok ? Icons.my_location : Icons.location_disabled, size: 16, color: ok ? kAct : kAmb),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: tx(12, color: ok ? kMute : kAmb, weight: FontWeight.w600))),
        ]);
      },
    );
  }
}
