import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';
import 'product_screen.dart';

class SubcategoryScreen extends StatelessWidget {
  final SubCategory sub;
  const SubcategoryScreen({super.key, required this.sub});

  @override
  Widget build(BuildContext context) {
    final products = kProducts.where((p) => p.sub == sub.name).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(sub.name, subtitle: '${kStores.length} stores near you'),
      bottomNavigationBar: const CartBar(),
      body: products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(sub.emoji, style: const TextStyle(fontSize: 54)),
                  const SizedBox(height: 10),
                  Text('Nothing here yet', style: head(18)),
                  const SizedBox(height: 6),
                  Text('Stores near you haven’t listed ${sub.name.toLowerCase()} yet.',
                      textAlign: TextAlign.center, style: body(13.5, color: kMute)),
                ]),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72),
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                final ls = listingsForProduct(p.id).where((l) => l.stock > 0).toList();
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
                  child: CardBox(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text(p.emoji, style: const TextStyle(fontSize: 54)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(p.size, style: body(11, color: kMute)),
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(ls.isEmpty ? 'Out of stock nearby' : '${ls.length} store${ls.length > 1 ? 's' : ''} · from ${rupees(ls.first.price)}',
                          style: body(11.5, color: ls.isEmpty ? kRed : kGD, weight: FontWeight.w600)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
