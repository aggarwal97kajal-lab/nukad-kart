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
        _Gallery(product),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (product.veg.isNotEmpty) ...[_VegMark(product.veg == 'veg'), SizedBox(width: 6)],
              Expanded(child: Text(product.sub.toUpperCase(), style: body(11.5, color: kMute, weight: FontWeight.w800))),
            ]),
            SizedBox(height: 4),
            Text(product.name, style: head(21)),
            Text('${product.size} · MRP ${rupees(product.mrp)}', style: body(13, color: kMute)),
            if (lowest != null) ...[
              SizedBox(height: 6),
              Text(tr('From {0} near you', [rupees(lowest)]), style: body(15, weight: FontWeight.w800)),
            ],
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
            if (_hasDetails) ...[
              SizedBox(height: 18),
              Text(t('Product details'), style: head(16)),
              SizedBox(height: 8),
              CardBox(
                padding: EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (product.desc.isNotEmpty) Text(product.desc, style: body(13.5)),
                  for (final (k, v) in [
                    (t('Brand'), product.brand),
                    (t('Size'), product.size),
                    (t('Type'), product.veg == 'veg' ? t('Veg') : product.veg == 'nonveg' ? t('Non-veg') : ''),
                    (t('Ingredients'), product.ingredients),
                    (t('Best before'), product.shelf),
                  ])
                    if (v.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k, style: body(11.5, color: kMute, weight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text(v, style: body(13.5)),
                        ]),
                      ),
                ]),
              ),
              SizedBox(height: 6),
              Text(t('Details are added by the shop.'), style: body(11, color: kMute)),
            ],
          ]),
        ),
      ]),
    );
  }

  bool get _hasDetails => [product.desc, product.brand, product.veg, product.ingredients, product.shelf].any((x) => x.isNotEmpty);

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

/// Big photos you swipe (up to 5), with dots; tap to open full screen and pinch to zoom.
class _Gallery extends StatefulWidget {
  final Product product;
  const _Gallery(this.product);
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int i = 0;

  @override
  Widget build(BuildContext context) {
    final pics = widget.product.photos.isNotEmpty ? widget.product.photos : [widget.product.emoji];
    return Container(
      height: 320,
      color: kCream,
      child: Stack(children: [
        PageView.builder(
          itemCount: pics.length,
          onPageChanged: (v) => setState(() => i = v),
          itemBuilder: (context, n) => GestureDetector(
            onTap: isPicture(pics[n]) ? () => _full(context, pics, n) : null,
            child: Center(child: Padding(padding: EdgeInsets.all(16), child: ProductPic(pics[n], size: 280))),
          ),
        ),
        if (pics.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var n = 0; n < pics.length; n++)
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  width: n == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: n == i ? kInk : kMute.withAlpha(90), borderRadius: BorderRadius.circular(4)),
                ),
            ]),
          ),
      ]),
    );
  }

  void _full(BuildContext context, List<String> pics, int start) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: PageView.builder(
            controller: PageController(initialPage: start),
            itemCount: pics.length,
            itemBuilder: (_, n) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: pics[n].startsWith('http')
                    ? Image.network(pics[n], fit: BoxFit.contain)
                    : Image.asset(pics[n], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The FSSAI veg / non-veg square.
class _VegMark extends StatelessWidget {
  final bool veg;
  const _VegMark(this.veg);
  @override
  Widget build(BuildContext context) {
    final c = veg ? Color(0xFF1B8A3C) : Color(0xFF9B2B1E);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(border: Border.all(color: c, width: 1.6), borderRadius: BorderRadius.circular(3)),
      alignment: Alignment.center,
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }
}
