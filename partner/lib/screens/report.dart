import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../ui.dart';

/// Reports: what the app brought this seller — this week (last 7 days), this month, last month.
/// Opened from the home card, the ⋮ menu and the Sunday push.
class WeekReportScreen extends StatefulWidget {
  const WeekReportScreen({super.key});
  @override
  State<WeekReportScreen> createState() => _WeekReportScreenState();
}

class _WeekReportScreenState extends State<WeekReportScreen> {
  Map<String, dynamic>? r;
  bool loading = true;
  String period = 'week';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await api.call('GET', '/v1/partner/report?period=$period');
      r = Map<String, dynamic>.from(res['report'] as Map);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  void _period(String p) {
    if (p == period) return;
    setState(() {
      period = p;
      loading = true;
    });
    _load();
  }

  /// Day-by-day bars: sales (shop) or calls (thela).
  Widget _chart(List<Map<String, dynamic>> days, bool thela) {
    num val(Map<String, dynamic> d) => (thela ? d['calls'] : d['sales']) as num? ?? 0;
    final max = days.fold<num>(0, (m, d) => val(d) > m ? val(d) : m);
    final best = days.isEmpty || max == 0 ? null : days.firstWhere((d) => val(d) == max);
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(thela ? tr('Calls, day by day') : tr('Sales, day by day'), style: tx(14, weight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in days)
              Expanded(
                child: Tooltip(
                  message: '${d['day']}: ${thela ? d['calls'] : '₹${d['sales']}'}',
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: days.length > 10 ? 1 : 4),
                    height: max == 0 ? 3 : 3 + 100 * val(d) / max,
                    decoration: BoxDecoration(color: d == best ? kAct : kAct.withAlpha(110), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        if (days.isNotEmpty)
          Row(children: [
            Text('${days.first['day']}'.substring(5), style: tx(11, color: kMute)),
            const Spacer(),
            Text('${days.last['day']}'.substring(5), style: tx(11, color: kMute)),
          ]),
        if (best != null) ...[
          const SizedBox(height: 4),
          Text(tr('Best day: {0} · {1}', [best['day'], thela ? best['calls'] : '₹${best['sales']}']), style: tx(12.5, color: kMute)),
        ],
      ]),
    );
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
      tr('My report on Nukkad Kart ({0} – {1})', [r['from'], r['to']]),
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
    final days = ((x?['days'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final top = ((x?['top'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final chips = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(spacing: 8, children: [
        for (final (v, label) in [('week', tr('This week')), ('month', tr('This month')), ('last', tr('Last month'))])
          ChoiceChip(label: Text(label), selected: period == v, onSelected: (_) => _period(v)),
      ]),
    );
    return Scaffold(
      appBar: bar(tr('Reports')),
      body: Column(children: [
        chips,
        Expanded(
          child: loading
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
                      Box(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('Sales through the app: ₹{0}', [x['sales']]), style: tx(14, weight: FontWeight.w800)),
                          if ((x['missed'] as num? ?? 0) > 0) ...[
                            const SizedBox(height: 4),
                            Text(tr('{0} orders missed (not accepted in 5 minutes)', [x['missed']]), style: tx(13, color: kRed, weight: FontWeight.w700)),
                          ],
                        ]),
                      ),
                    if (days.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _chart(days, thela),
                    ],
                    if (!thela && top.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Box(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('Top items'), style: tx(14, weight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          for (final (i, it) in top.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Text('${i + 1}.  ', style: tx(13.5, color: kMute)),
                                Expanded(child: Text('${it['name']}', style: tx(13.5))),
                                Text(tr('{0} sold · ₹{1}', [it['qty'], it['amount']]), style: tx(13, color: kMute)),
                              ]),
                            ),
                        ]),
                      ),
                    ],
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
        ),
      ]),
    );
  }
}
