import 'package:flutter/material.dart';
import '../api.dart';
import '../catalog.dart';
import '../produce.dart';
import '../session.dart';
import '../ui.dart';
import 'product_form.dart';

/// Thela "Products": tap a photo, type today's price. No forms, no barcode.
class ProducePickerScreen extends StatefulWidget {
  const ProducePickerScreen({super.key});
  @override
  State<ProducePickerScreen> createState() => _ProducePickerScreenState();
}

class _ProducePickerScreenState extends State<ProducePickerScreen> {
  final Map<String, Map<String, dynamic>> mine = {}; // produce key → my product
  String tab = 'veg', q = '';
  bool more = false, _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/products?all=1');
      mine.clear();
      for (final e in (r['products'] as List? ?? [])) {
        final p = Map<String, dynamic>.from(e as Map);
        if (p['produceKey'] != null) mine['${p['produceKey']}'] = p;
      }
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  String label(Produce p) => gLang == 'hi' && p.hi.isNotEmpty ? p.hi : p.name;

  List<Produce> get shown {
    final s = q.trim().toLowerCase();
    Iterable<Produce> l = kProduce;
    if (s.isNotEmpty) {
      l = l.where((p) => '${p.name} ${p.en} ${p.hi} ${p.words} ${p.key}'.toLowerCase().contains(s));
    } else if (tab == 'selling') {
      l = l.where((p) => mine[p.key]?['inStock'] == true);
    } else {
      l = l.where((p) => p.cat == tab && (more || p.common || mine.containsKey(p.key)));
    }
    return l.toList();
  }

  Future<void> _open(Produce p) async {
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (_) => _PriceSheet(item: p, current: mine[p.key], label: label(p)),
    );
    if (r != null && mounted) {
      setState(() => mine[p.key] = r);
      // Changing a price counts as today's prices being checked.
      api.call('POST', '/v1/partner/products/confirm-prices').then((_) => session.refresh()).catchError((_) {});
    }
  }

  Widget _tab(String v, String text) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(text), selected: tab == v && q.isEmpty, onSelected: (_) => setState(() => tab = v)),
      );

  @override
  Widget build(BuildContext context) {
    final selling = mine.values.where((p) => p['inStock'] == true).length;
    final list = shown;
    return Scaffold(
      appBar: bar(t('What are you selling today?'), actions: [
        Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(tr('{0} selling', [selling]), style: tx(12.5, color: kOnHeader, weight: FontWeight.w700)))),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: TextField(
                      onChanged: (v) => setState(() => q = v),
                      decoration: field(t('Search: aloo, tamatar, kela…')).copyWith(prefixIcon: const Icon(Icons.search)),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                      _tab('veg', t('Vegetables')),
                      _tab('fruit', t('Fruits')),
                      _tab('selling', tr('Selling now · {0}', [selling])),
                    ]),
                  ),
                ),
                if (list.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(tab == 'selling' && q.isEmpty ? t('Tap items in Vegetables or Fruits and type today’s price.') : t('Nothing matches'),
                          textAlign: TextAlign.center, style: tx(14, color: kMute)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.78),
                      delegate: SliverChildBuilderDelegate((_, i) => _tile(list[i]), childCount: list.length),
                    ),
                  ),
                if (q.isEmpty && tab != 'selling')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      child: OutlinedButton(
                        onPressed: () => setState(() => more = !more),
                        child: Text(more ? t('Show only common items') : t('More types (cherry tomato, kiwi, avocado…)')),
                      ),
                    ),
                  ),
              ]),
            ),
    );
  }

  Widget _tile(Produce p) {
    final m = mine[p.key];
    final on = m?['inStock'] == true;
    return GestureDetector(
      onTap: () => _open(p),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: on ? kOkBg : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? kAct : kLine, width: on ? 2 : 1),
        ),
        child: Column(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(color: Colors.white, child: Image.asset(p.image, fit: BoxFit.contain))),
              if (on)
                Positioned(
                  left: 3,
                  top: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF315426), borderRadius: BorderRadius.circular(6)),
                    child: Text('${money(m!['price'] as num)}/${t('${m['unit']}')}', style: tx(10.5, color: Colors.white, weight: FontWeight.w700)),
                  ),
                ),
              if (on)
                const Positioned(right: 3, top: 3, child: CircleAvatar(radius: 9, backgroundColor: Color(0xFF315426), child: Icon(Icons.check, size: 12, color: Colors.white))),
              if (m != null && !on)
                Positioned(
                  left: 3,
                  top: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: kLocked, borderRadius: BorderRadius.circular(6)),
                    child: Text(t('Not today'), style: tx(10, color: kMute, weight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(label(p), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tx(12, weight: FontWeight.w800)),
          if (gLang != 'hi' && p.common && p.en != p.name)
            Text(p.en, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(10, color: kMute)),
        ]),
      ),
    );
  }
}

class _PriceSheet extends StatefulWidget {
  final Produce item;
  final Map<String, dynamic>? current;
  final String label;
  const _PriceSheet({required this.item, required this.current, required this.label});
  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late String unit = '${widget.current?['unit'] ?? widget.item.unit}';
  late final price = TextEditingController(text: widget.current == null ? '' : _n(widget.current!['price'] as num));
  bool _busy = false;

  String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }

  void _step(int d) {
    final v = (double.tryParse(price.text) ?? 0) + d;
    if (v < 0) return;
    setState(() => price.text = _n(v));
  }

  Future<void> _save(bool selling) async {
    final p = double.tryParse(price.text.trim());
    if (selling && (p == null || p <= 0)) {
      toast(context, t('Enter today’s price.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final Map<String, dynamic> r;
      if (!selling) {
        r = await api.call('PATCH', '/v1/partner/products/${widget.current!['id']}/stock', {'inStock': false});
      } else {
        final it = widget.item;
        r = await api.call('POST', '/v1/partner/products', {
          if (widget.current != null) 'id': widget.current!['id'],
          'kind': 'loose',
          'produceKey': it.key,
          'name': it.common && it.en != it.name ? '${it.name} (${it.en})' : it.name,
          'category': it.cat == 'fruit' ? 'Fruits' : 'Vegetables',
          'unit': unit,
          'options': kThelaSizes[unit],
          'price': p,
          'gst': 0,
          'inStock': true,
        });
      }
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(r['product'] as Map));
      return;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = double.tryParse(price.text.trim());
    final cur = widget.current;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(color: Colors.white, width: 56, height: 56, child: Image.asset(widget.item.image))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.label, style: tx(17, weight: FontWeight.w800)),
              if (cur != null) Text(tr('Last price {0}/{1}', [money(cur['price'] as num), t('${cur['unit']}')]), style: tx(12, color: kMute)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(t('Sold by'), style: tx(12, color: kMute, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final u in const ['kg', 'piece', 'dozen', 'bunch'])
            ChoiceChip(label: Text(t(u)), selected: unit == u, onSelected: (_) => setState(() => unit = u)),
        ]),
        const SizedBox(height: 12),
        Text(tr('Today’s price per {0}', [t(unit)]), style: tx(12, color: kMute, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          IconButton.outlined(onPressed: () => _step(-5), icon: const Text('−5')),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: price,
              autofocus: cur == null,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: tx(22, weight: FontWeight.w800),
              decoration: field('40').copyWith(prefixText: '₹ '),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(onPressed: () => _step(5), icon: const Text('+5')),
        ]),
        if (p != null && p > 0) ...[
          const SizedBox(height: 8),
          Text(
              '${t('Customers can buy')}: ${kThelaSizes[unit]!.map((n) => '${sizeLabel(unit, n)} ${money(sizePrice(unit, p, n))}').join(' · ')}',
              style: tx(12, color: kMute)),
        ],
        const SizedBox(height: 14),
        Btn(_busy ? t('Saving…') : t('Selling today'), onTap: _busy ? null : () => _save(true)),
        if (cur != null && cur['inStock'] == true)
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _save(false),
              child: Text(t('Not selling today'), style: TextStyle(color: kRed)),
            ),
          ),
      ]),
    );
  }
}
