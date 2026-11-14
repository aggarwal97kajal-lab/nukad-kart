import 'package:flutter/material.dart';
import '../l10n.dart';
import '../services/api.dart';
import 'ui.dart';

/// "Aaj ke daam": a tile that opens today's vegetable / fruit prices at the 3 nearest thelas and 2 nearest
/// kiranas, one row per item, the cheapest marked ✓. Prices older than 2 days are not shown.
class TodayPricesTile extends StatelessWidget {
  final double lat, lng;
  const TodayPricesTile({super.key, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodayPricesScreen(lat: lat, lng: lng))),
      child: CardBox(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          EmojiTile('🍅', size: 46, bg: kGBg),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Today’s prices near you'), style: head(15)),
              SizedBox(height: 2),
              Text(t('Compare tomato, potato, onion… at nearby thelas and kiranas'), style: body(12, color: kMute)),
            ]),
          ),
          Icon(Icons.chevron_right, color: kMute),
        ]),
      ),
    );
  }
}

class TodayPricesScreen extends StatefulWidget {
  final double lat, lng;
  const TodayPricesScreen({super.key, required this.lat, required this.lng});
  @override
  State<TodayPricesScreen> createState() => _TodayPricesScreenState();
}

class _TodayPricesScreenState extends State<TodayPricesScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.todayPrices(widget.lat, widget.lng);
      if (mounted) setState(() => data = r);
    } catch (e) {
      if (mounted) setState(() => error = t('Could not load prices. Pull to try again.'));
    }
  }

  static String _unit(String u) => switch (u) { 'piece' => t('pc'), 'litre' => 'L', 'dozen' => t('dozen'), 'bunch' => t('bunch'), _ => u };

  /// "Tamatar (Tomato)" → "Tamatar"; the English name goes under it.
  static (String, String) _names(String n) {
    final m = RegExp(r'^(.*?)\s*\((.*)\)$').firstMatch(n);
    return m == null ? (n, '') : (m.group(1)!, m.group(2)!);
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final sellers = ((d?['sellers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final items = ((d?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(t('Today’s prices'), subtitle: t('3 nearest thelas + 2 nearest kiranas')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          if (d == null && error == null) Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator())),
          if (error != null) Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text(error!, style: body(13, color: kMute)))),
          if (d != null && items.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                  child: Text(t('No fresh prices near you right now. Sellers update them every morning.'),
                      textAlign: TextAlign.center, style: body(13, color: kMute))),
            ),
          if (items.isNotEmpty) ...[
            CardBox(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 14,
                  horizontalMargin: 12,
                  headingRowHeight: 58,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 58,
                  columns: [
                    DataColumn(label: Text(t('Item'), style: body(12, color: kMute, weight: FontWeight.w800))),
                    for (final s in sellers)
                      DataColumn(
                        numeric: true,
                        label: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(s['kind'] == 'thela' ? '🛒' : '🏪', style: TextStyle(fontSize: 14)),
                          SizedBox(
                            width: 72,
                            child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                                style: body(11.5, weight: FontWeight.w800)),
                          ),
                          Text('${s['distanceM']} m', style: body(10.5, color: kMute)),
                        ]),
                      ),
                  ],
                  rows: [
                    for (final it in items)
                      DataRow(cells: [
                        DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_names('${it['name']}').$1, style: body(13.5, weight: FontWeight.w700)),
                          Text('${_names('${it['name']}').$2.isEmpty ? '' : '${_names('${it['name']}').$2} · '}/${_unit('${it['unit']}')}',
                              style: body(11, color: kMute)),
                        ])),
                        for (final s in sellers) _cell(it, '${s['id']}'),
                      ]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kGBg, borderRadius: BorderRadius.circular(6)),
                child: Text('✓ ₹', style: body(11.5, color: kGText, weight: FontWeight.w800)),
              ),
              SizedBox(width: 8),
              Expanded(child: Text(t('Cheapest here today.'), style: body(11.5, color: kMute))),
            ]),
            SizedBox(height: 6),
            Text(t('Prices are set by each seller. “—” = not sold there, or the price is more than 2 days old.'),
                style: body(11.5, color: kMute)),
          ],
        ]),
      ),
    );
  }

  DataCell _cell(Map<String, dynamic> it, String sellerId) {
    final p = (it['prices'] as Map?)?[sellerId] as num?;
    if (p == null) return DataCell(Text('—', style: body(13, color: kMute)));
    final best = ((it['best'] as List?) ?? []).contains(sellerId);
    final txt = '₹${p == p.roundToDouble() ? p.toInt() : p.toStringAsFixed(1)}';
    return DataCell(best
        ? Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: kGBg, borderRadius: BorderRadius.circular(7)),
            child: Text('✓ $txt', style: body(13.5, color: kGText, weight: FontWeight.w800)),
          )
        : Text(txt, style: body(13.5, weight: FontWeight.w600)));
  }
}
