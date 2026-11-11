import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';
import 'product_screen.dart';

class SubcategoryScreen extends StatelessWidget {
  final SubCategory sub;
  const SubcategoryScreen({super.key, required this.sub});

  @override
  Widget build(BuildContext context) {
    final st8 = AppScope.of(context);
    int nearby(Product p) => listingsForProduct(p.id).where((l) => st8.stockOf(l) > 0).length;
    final raw = kProducts.where((p) => p.sub == sub.name).toList();
    final products = [...raw.where((p) => nearby(p) > 0), ...raw.where((p) => nearby(p) == 0)];
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(sub.name, subtitle: '${kStores.length} stores near you'),
      bottomNavigationBar: CartBar(),
      body: products.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(sub.emoji, style: TextStyle(fontSize: 54)),
                  SizedBox(height: 10),
                  Text('Nothing here yet', style: head(18)),
                  SizedBox(height: 6),
                  Text('Stores near you haven’t listed ${sub.name.toLowerCase()} yet.',
                      textAlign: TextAlign.center, style: body(13.5, color: kMute)),
                ]),
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72),
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                final ls = listingsForProduct(p.id).where((l) => st8.stockOf(l) > 0).toList();
                final out = ls.isEmpty;
                final first = listingsForProduct(p.id);
                final storeId = first.isEmpty ? '' : first.first.storeId;
                final on = storeId.isNotEmpty && st8.isNotifyOn(storeId, p.id);
                final image = Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(p.emoji, style: TextStyle(fontSize: 54)),
                );
                final card = CardBox(
                  padding: EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Stack(children: [
                        Positioned.fill(child: out ? Opacity(opacity: 0.45, child: greyed(image)) : image),
                        if (out)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: kCard, borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
                              child: Text(t('Out of stock'), style: body(11, weight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ),
                    SizedBox(height: 8),
                    Opacity(
                      opacity: out ? 0.5 : 1.0,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.size, style: body(11, color: kMute)),
                        Text(p.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w700)),
                      ]),
                    ),
                    SizedBox(height: 4),
                    out
                        ? NotifyButton(
                            on: on,
                            onTap: () {
                              if (storeId.isEmpty) return;
                              st8.toggleNotify(storeId, p.id);
                              showToast(context, on ? 'Alert turned off' : '🔔 We’ll notify you when ${p.name} is back');
                            },
                          )
                        : Text('${ls.length} store${ls.length > 1 ? 's' : ''} · from ${rupees(ls.first.price)}',
                            style: body(11.5, color: kGText, weight: FontWeight.w600)),
                  ]),
                );
                if (out) return card;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
                  child: card,
                );
              },
            ),
    );
  }
}
