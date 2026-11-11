import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../widgets/ui.dart';
import 'product_screen.dart';
import 'store_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();
    final products = query.isEmpty
        ? <Product>[]
        : kProducts
            .where((p) => p.name.toLowerCase().contains(query) || p.sub.toLowerCase().contains(query))
            .toList();
    final stores = query.isEmpty ? <Store>[] : kStores.where((s) => s.name.toLowerCase().contains(query)).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: kInk,
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          controller: _ctl,
          onChanged: (v) => setState(() => q = v),
          style: body(15.5, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Search atta, doodh, tamatar…',
            hintStyle: body(15, color: kMute),
            border: InputBorder.none,
          ),
        ),
      ),
      body: query.isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: [
              Text('Popular near you', style: head(15)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in ['Atta', 'Milk', 'Tomato', 'Noodles', 'Diya', 'Soap'])
                  ActionChip(
                    label: Text(t, style: body(13, weight: FontWeight.w600)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kLine),
                    onPressed: () => setState(() {
                      q = t;
                      _ctl.text = t;
                    }),
                  ),
              ]),
            ])
          : ListView(padding: const EdgeInsets.all(12), children: [
              if (products.isEmpty && stores.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text('No match for “$q” near you', textAlign: TextAlign.center, style: body(14, color: kMute)),
                ),
              for (final st in stores)
                ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.storefront, color: kG),
                  title: Text(st.name, style: body(14.5, weight: FontWeight.w700)),
                  subtitle: Text('${st.distanceM} m · store', style: body(12, color: kMute)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(store: st))),
                ),
              for (final p in products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
                    child: CardBox(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        EmojiTile(p.emoji, size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: body(14, weight: FontWeight.w700)),
                            Text('${p.size} · ${p.sub}', style: body(12, color: kMute)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: kMute),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}
