import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import 'pass.dart';
import 'admin.dart';

String dateText(int secs) {
  final d = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

  Future<void> _setLive(bool on) async {
    setState(() => _busy = true);
    try {
      final r = await api.call('POST', '/v1/partner/live', {'on': on});
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  (String, String, Color, Color) _status(Map<String, dynamic> s) {
    final reason = s['offlineReason'];
    return switch (reason) {
      null => ('You are LIVE', 'Customers within 500 m can see you and order.', Colors.white, kAct),
      'no_pass' => ('Pass ended · hidden', 'Customers can’t see you. Buy a pass to go live.', kRed, kRedBg),
      'blocked' => ('Account blocked', 'Contact Nukad Kart support.', kRed, kRedBg),
      'closed_now' => ('Closed now', 'Outside your timings (${s['opensAt']} – ${s['closesAt']}). You show again at opening time.', kAmb, kAmbBg),
      'missed_orders' => ('Offline for today', '3 orders were missed today. Switch on to go live again.', kAmb, kAmbBg),
      _ => ('You are offline', 'Switch on to show your shop to customers.', kInk, kSurf),
    };
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
                tooltip: 'Admin',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'out') session.signOut();
              },
              itemBuilder: (_) => [PopupMenuItem(value: 'out', child: Text('Log out (${session.email})'))],
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
                      Text(title, style: tx(18, color: s['offlineReason'] == null ? Colors.white : fg, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sub, style: tx(12.5, color: s['offlineReason'] == null ? Colors.white : kInk)),
                    ]),
                  ),
                  Switch(
                    value: s['live'] == true,
                    activeThumbColor: kBrand,
                    onChanged: _busy || (!passActive && s['live'] != true) ? null : _setLive,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Box(
                child: Row(children: [
                  const Icon(Icons.confirmation_number_outlined, color: kAct, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(passActive ? 'Pass active · $daysLeft day${daysLeft == 1 ? '' : 's'} left' : 'No active pass',
                          style: tx(15, weight: FontWeight.w800)),
                      Text(passActive ? 'Ends ${dateText(passUntil)}' : 'Your shop shows to customers only with a pass.',
                          style: tx(12.5, color: kMute)),
                    ]),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassScreen())),
                    style: FilledButton.styleFrom(backgroundColor: kAct),
                    child: Text(passActive ? 'Extend' : 'Buy pass'),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today', style: tx(15, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Missed orders: ${s['missedToday'] ?? 0} of 3', style: tx(13)),
                  Text('Orders arrive here soon. A new order rings until you accept it (5 minutes).', style: tx(12, color: kMute)),
                ]),
              ),
              if (session.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Pass payments', style: tx(15, weight: FontWeight.w800)),
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
      'PAID' => ('Paid', kAct, kOkBg),
      'CHECKING' => ('Being checked', kAmb, kAmbBg),
      'FAILED' => ('Failed', kRed, kRedBg),
      'CANCELLED' => ('Not received', kRed, kRedBg),
      _ => ('Not finished', kMute, kSurf),
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
