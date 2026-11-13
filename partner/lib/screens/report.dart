import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../ui.dart';

/// Sunday report: what the app brought this seller in the last 7 days (also opened from the Sunday push).
class WeekReportScreen extends StatefulWidget {
  const WeekReportScreen({super.key});
  @override
  State<WeekReportScreen> createState() => _WeekReportScreenState();
}

class _WeekReportScreenState extends State<WeekReportScreen> {
  Map<String, dynamic>? r;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await api.call('GET', '/v1/partner/report');
      r = Map<String, dynamic>.from(res['report'] as Map);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  Widget _num(String n, String label) => Expanded(
        child: Column(children: [
          Text(n, style: tx(26, color: kAct, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: tx(12, color: kMute)),
        ]),
      );

  String _text(Map<String, dynamic> r, bool thela) {
    final lines = <String>[
      tr('My week on Nukad Kart ({0} – {1})', [r['from'], r['to']]),
      tr('{0} times people looked at my {1}', [r['views'], thela ? tr('thela') : tr('shop')]),
      if (thela) tr('{0} calls to their street', [r['calls']]) else tr('{0} orders · ₹{1}', [r['orders'], r['sales']]),
      tr('{0} new customers', [r['newCustomers']]),
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final x = r;
    final thela = x?['kind'] == 'thela';
    final streets = ((x?['streets'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Scaffold(
      appBar: bar(tr('Weekly report')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : x == null
              ? Center(child: Text(tr('Could not load the report.'), style: tx(14, color: kMute)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text(tr('{0} – {1} · {2}', [x['from'], x['to'], x['name']]), style: tx(13, color: kMute)),
                    const SizedBox(height: 10),
                    Box(
                      border: kAct,
                      child: Row(children: [
                        _num('${x['views']}', tr('times people looked at you')),
                        if (thela) _num('${x['calls']}', tr('called you to their street')) else _num('${x['orders']}', tr('orders delivered')),
                        _num('${x['newCustomers']}', tr('new customers')),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (thela)
                      Box(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('Chats: {0} · You went to: {1}', [x['chats'], x['went']]), style: tx(14, weight: FontWeight.w800)),
                        ]),
                      )
                    else
                      Box(child: Text(tr('Sales through the app: ₹{0}', [x['sales']]), style: tx(14, weight: FontWeight.w800))),
                    if (streets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Box(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('Most calls came from'), style: tx(14, weight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          for (final s in streets) Text(tr('{0} · {1} times', [s['address'], s['count']]), style: tx(13.5)),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Btn(tr('Share on WhatsApp'), outline: true, onTap: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_text(x, thela))}'), mode: LaunchMode.externalApplication)),
                    const SizedBox(height: 8),
                    Text(tr('Counted only in the app: phone calls you get directly are not in this report.'), style: tx(11.5, color: kMute)),
                  ]),
                ),
    );
  }
}
