import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../catalog.dart';
import '../ui.dart';
import 'product_form.dart';
import 'scanner.dart';

/// Products tab: search, category / out-of-stock filters, quick in-stock switch, add.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final q = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> cats = [];
  int total = 0, outOfStock = 0;
  String filter = 'all', cat = '';
  bool more = false, _loading = true, _loadingMore = false;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
    scroll.addListener(() {
      if (more && !_loadingMore && scroll.position.pixels > scroll.position.maxScrollExtent - 400) _load(next: true);
    });
  }

  @override
  void dispose() {
    q.dispose();
    scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final seq = ++_seq;
    if (next) {
      setState(() => _loadingMore = true);
    }
    final params = <String>[
      if (q.text.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(q.text.trim())}',
      if (filter == 'out') 'filter=out',
      if (cat.isNotEmpty) 'cat=${Uri.encodeQueryComponent(cat)}',
      if (next && items.isNotEmpty) 'before=${Uri.encodeQueryComponent('${items.last['name']}')}',
    ];
    try {
      final r = await api.call('GET', '/v1/partner/products${params.isEmpty ? '' : '?${params.join('&')}'}');
      if (seq != _seq || !mounted) return;
      final page = ((r['products'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        items = next ? [...items, ...page] : page;
        more = r['more'] == true;
        total = (r['total'] as num?)?.toInt() ?? 0;
        outOfStock = (r['outOfStock'] as num?)?.toInt() ?? 0;
        cats = ((r['categories'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _search(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  /// Quick switch on the list: moves at once, the server confirms.
  Future<void> _toggle(Map<String, dynamic> p, bool v) async {
    final i = items.indexOf(p);
    final before = Map<String, dynamic>.from(p);
    setState(() => items[i] = {...p, 'inStock': v, if (p['stock'] != null) 'stock': v ? ((p['stock'] as num) > 0 ? p['stock'] : 1) : 0});
    try {
      final r = await api.call('PATCH', '/v1/partner/products/${p['id']}/stock',
          p['stock'] != null ? {'stock': items[i]['stock']} : {'inStock': v});
      if (mounted) setState(() => items[i] = Map<String, dynamic>.from(r['product'] as Map));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => items[i] = before);
      toast(context, e.message);
    }
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final r = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
    if (r != null) _load();
  }

  Future<void> _add() async {
    final how = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: Text(t('Add product'), style: tx(18, weight: FontWeight.w800))),
          _way(ctx, 'scan', Icons.qr_code_scanner, t('Scan barcode'), t('Packed items: name and photo fill in')),
          _way(ctx, 'loose', Icons.scale_outlined, t('Loose item'), t('Atta, dal, rice, sabzi sold by kg, litre or piece')),
          _way(ctx, 'type', Icons.edit_outlined, t('Type it yourself'), t('No barcode? Add name, photo and price')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    final Widget page = switch (how) {
      'scan' => const ScannerScreen(),
      'loose' => const LoosePickerScreen(),
      _ => const ProductFormScreen(),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Widget _way(BuildContext ctx, String v, IconData icon, String title, String sub) => ListTile(
        leading: Icon(icon, color: kAct, size: 30),
        title: Text(title, style: tx(15, weight: FontWeight.w800)),
        subtitle: Text(sub, style: tx(12, color: kMute)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pop(ctx, v),
      );

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Products'), actions: [
        Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(tr('{0} items', [total]), style: tx(12.5, color: kOnHeader)))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(t('Add product'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(controller: q, onChanged: _search, decoration: field(t('Search your products')).copyWith(prefixIcon: const Icon(Icons.search))),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            _chip(t('All'), filter == 'all' && cat.isEmpty, () {
              filter = 'all';
              cat = '';
              _load();
            }),
            _chip(tr('Out of stock · {0}', [outOfStock]), filter == 'out', () {
              filter = filter == 'out' ? 'all' : 'out';
              _load();
            }),
            for (final c in cats)
              _chip('${t('${c['name']}')} · ${c['count']}', cat == c['name'], () {
                cat = cat == c['name'] ? '' : '${c['name']}';
                _load();
              }),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Icon(Icons.inventory_2_outlined, size: 56, color: kMute),
                          const SizedBox(height: 10),
                          Text(total == 0 ? t('Add your first product') : t('Nothing matches'),
                              textAlign: TextAlign.center, style: tx(17, weight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(total == 0 ? t('Scan packets or pick loose items from the ready list.') : t('Try another search or filter.'),
                              textAlign: TextAlign.center, style: tx(13, color: kMute)),
                        ])
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          itemCount: items.length + (more ? 1 : 0),
                          itemBuilder: (_, i) => i == items.length
                              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                              : _row(items[i]),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final loose = p['kind'] == 'loose';
    final price = p['price'] as num;
    final mrp = p['mrp'] as num?;
    final on = p['inStock'] == true;
    final info = loose
        ? '${money(price)}/${t('${p['unit']}')}'
        : '${p['size']} · ${money(price)}${mrp != null && mrp > price ? '  (MRP ${money(mrp)})' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: on ? 1 : 0.6,
        child: InkWell(
          onTap: () => _edit(p),
          borderRadius: BorderRadius.circular(16),
          child: Box(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              productImage(p),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(14.5, weight: FontWeight.w800)),
                  Text(info, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(12, color: kMute)),
                  if (!on)
                    Text(t('Out of stock'), style: tx(11.5, color: kRed, weight: FontWeight.w700))
                  else if (p['stock'] != null)
                    Text(tr('{0} left', [p['stock']]), style: tx(11.5, color: kAct, weight: FontWeight.w700)),
                ]),
              ),
              Switch(value: on, onChanged: (v) => _toggle(p, v)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ready list of loose items: pick one, type the price.
class LoosePickerScreen extends StatefulWidget {
  const LoosePickerScreen({super.key});
  @override
  State<LoosePickerScreen> createState() => _LoosePickerScreenState();
}

class _LoosePickerScreenState extends State<LoosePickerScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = kLooseItems.where((l) => q.isEmpty || l.name.toLowerCase().contains(q) || t(l.name).toLowerCase().contains(q)).toList();
    final byCat = <String, List<Loose>>{};
    for (final l in list) {
      (byCat[l.cat] ??= []).add(l);
    }
    return Scaffold(
      appBar: bar(t('Loose item')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(
          autofocus: false,
          onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
          decoration: field(t('Search: toor dal, potato…')).copyWith(prefixIcon: const Icon(Icons.search)),
        ),
        const SizedBox(height: 6),
        for (final e in byCat.entries) ...[
          Builder(builder: (_) {
            final c = catByName(e.key)!;
            final ok = canSellCat(c);
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset(c.image, width: 26, height: 26, fit: BoxFit.cover)),
                const SizedBox(width: 8),
                Text(t(e.key), style: tx(13.5, weight: FontWeight.w800)),
                if (!ok) ...[const SizedBox(width: 8), Text(t('Needs FSSAI'), style: tx(11.5, color: kAmb, weight: FontWeight.w700))],
              ]),
            );
          }),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in e.value)
              ActionChip(
                label: Text(t(l.name)),
                onPressed: canSellCat(catByName(l.cat)!)
                    ? () async {
                        final saved = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ProductFormScreen(loose: l)));
                        if (saved != null && context.mounted) Navigator.pop(context);
                      }
                    : null,
              ),
          ]),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProductFormScreen(looseBlank: true))),
          icon: const Icon(Icons.edit_outlined),
          label: Text(t('Not in the list? Add it yourself')),
        ),
      ]),
    );
  }
}
