import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';

class ProductScreen extends StatelessWidget {
  final Product product;
  const ProductScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ls = listingsForProduct(product.id);
    final inStock = ls.where((l) => l.stock > 0).toList();
    final lowest = inStock.isEmpty ? null : inStock.first.price;
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(product.name, subtitle: product.size),
      bottomNavigationBar: const CartBar(),
      body: ListView(children: [
        Container(
          height: 240,
          color: kCream,
          alignment: Alignment.center,
          child: Text(product.emoji, style: const TextStyle(fontSize: 130)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.sub.toUpperCase(), style: body(11.5, color: kMute, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(product.name, style: head(21)),
            Text('${product.size} · MRP ${rupees(product.mrp)}', style: body(13, color: kMute)),
            const SizedBox(height: 16),
            Text('Sold near you', style: head(16)),
            const SizedBox(height: 8),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(children: [
                for (var i = 0; i < ls.length; i++)
                  _row(context, s, ls[i], ls[i].price == lowest && ls[i].stock > 0, i == ls.length - 1),
              ]),
            ),
            const SizedBox(height: 10),
            Text('Only stores within 500 m are shown. Prices are set by each store and include GST.',
                style: body(11.5, color: kMute)),
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, AppState s, Listing l, bool best, bool last) {
    final st = storeById(l.storeId);
    final out = l.stock == 0;
    return Opacity(
      opacity: out ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: kLine))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: kGBg, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.storefront, color: kG, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(st.name, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700))),
                if (best) ...[const SizedBox(width: 6), const Pill('Lowest', color: kGD, bg: Color(0xFFD9F0CF))],
              ]),
              Text('${st.distanceM} m · ${out ? 'Out of stock' : '${l.stock} left'}',
                  style: body(11.5, color: out ? kRed : kMute)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rupees(l.price), style: head(16)),
            const SizedBox(height: 4),
            if (!out)
              QtyStepper(
                qty: s.qtyOf(l.storeId, product.id),
                onAdd: () => tryAddToCart(context, l.storeId, product.id),
                onRemove: () => s.remove(product.id),
              ),
          ]),
        ]),
      ),
    );
  }
}
