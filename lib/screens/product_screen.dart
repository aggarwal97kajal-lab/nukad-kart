import 'package:flutter/material.dart';
import '../l10n.dart';
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
    final all = listingsForProduct(product.id);
    final inStock = all.where((l) => s.stockOf(l) > 0).toList();
    final ls = [...inStock, ...all.where((l) => s.stockOf(l) == 0)];
    final lowest = inStock.isEmpty ? null : inStock.first.price;
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(product.name, subtitle: product.size, actions: [
        IconButton(
          onPressed: () {
            s.toggleWishlist(product.id);
            showToast(context, s.wishlist.contains(product.id) ? 'Added to your wishlist' : 'Removed from wishlist');
          },
          icon: Icon(s.wishlist.contains(product.id) ? Icons.favorite : Icons.favorite_border,
              color: s.wishlist.contains(product.id) ? kRed : kInk),
        ),
      ]),
      bottomNavigationBar: CartBar(),
      body: ListView(children: [
        Container(
          height: 240,
          color: kCream,
          alignment: Alignment.center,
          child: Text(product.emoji, style: TextStyle(fontSize: 130)),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.sub.toUpperCase(), style: body(11.5, color: kMute, weight: FontWeight.w800)),
            SizedBox(height: 4),
            Text(product.name, style: head(21)),
            Text('${product.size} · MRP ${rupees(product.mrp)}', style: body(13, color: kMute)),
            SizedBox(height: 16),
            Text(t('Sold near you'), style: head(16)),
            SizedBox(height: 8),
            CardBox(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(children: [
                for (var i = 0; i < ls.length; i++)
                  _row(context, s, ls[i], ls[i].price == lowest && s.stockOf(ls[i]) > 0, i == ls.length - 1),
              ]),
            ),
            SizedBox(height: 10),
            Text('Only stores within 500 m are shown. Prices are set by each store and include GST.',
                style: body(11.5, color: kMute)),
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, AppState s, Listing l, bool best, bool last) {
    final st = storeById(l.storeId);
    final stock = s.stockOf(l);
    final out = stock == 0;
    final info = Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: kGBg, borderRadius: BorderRadius.circular(11)),
        child: Icon(Icons.storefront, color: kG, size: 20),
      ),
      SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
          SizedBox(height: 2),
          Row(children: [
            Flexible(
              child: Text('${st.distanceM} m · ${out ? t('Out of stock') : '$stock left'} · ${rupees(l.price)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: out ? kRed : kMute)),
            ),
            if (best) ...[SizedBox(width: 6), Pill('Lowest', color: kGText, bg: kPillBg)],
          ]),
        ]),
      ),
    ]);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        Expanded(child: out ? Opacity(opacity: 0.45, child: info) : info),
        SizedBox(width: 12),
        out
            ? NotifyButton(
                on: s.isNotifyOn(l.storeId, product.id),
                onTap: () {
                  final wasOn = s.isNotifyOn(l.storeId, product.id);
                  s.toggleNotify(l.storeId, product.id);
                  showToast(context,
                      wasOn ? 'Alert turned off' : '🔔 We’ll notify you when it’s back at ${st.name}');
                },
              )
            : QtyStepper(
                qty: s.qtyOf(l.storeId, product.id),
                onAdd: () => tryAddToCart(context, l.storeId, product.id),
                onRemove: () => s.remove(product.id),
              ),
      ]),
    );
  }
}
