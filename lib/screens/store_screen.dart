import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';
import 'rating_sheet.dart';

class StoreScreen extends StatefulWidget {
  final Store store;
  const StoreScreen({super.key, required this.store});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = widget.store;
    final all = listingsForStore(st.id);
    final mains = <String>['All', ...kCategories.map((c) => c.name)];
    final shown = filter == 'All'
        ? all
        : all.where((l) {
            final p = productById(l.productId);
            final main = kCategories.firstWhere((c) => c.subs.any((sb) => sb.name == p.sub));
            return main.name == filter;
          }).toList();
    final myRating = s.ratings[st.id];
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: CartBar(),
      appBar: AppBar(
        backgroundColor: kCard,
        surfaceTintColor: kCard,
        foregroundColor: kInk,
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: () {
              s.toggleBookmark(st.id);
              showToast(context, s.bookmarks.contains(st.id) ? 'Store bookmarked' : 'Bookmark removed');
            },
            icon: Icon(s.bookmarks.contains(st.id) ? Icons.bookmark : Icons.bookmark_border,
                color: s.bookmarks.contains(st.id) ? kG : kInk),
          ),
        ],
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.name, style: head(18)),
          Text('${st.distanceM} m · Open till ${st.openTill} · ★ ${st.rating} (${st.ratingCount})',
              style: body(12, color: kMute)),
        ]),
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: kCard,
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (st.door) Pill(t('Door delivery')),
              if (st.pickup) Pill(t('Pickup'), color: kBlu, bg: kBluBg),
              Pill(t('Pay at delivery'), color: kGText, bg: kPillBg),
            ]),
            if (myRating != null) ...[
              SizedBox(height: 10),
              InkWell(
                onTap: () => showRatingSheet(context, vendorId: st.id, vendorName: st.name, editing: true),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Text(t('Your rating'), style: body(12.5, color: kMute)),
                    SizedBox(width: 8),
                    StarRow(value: myRating, size: 16),
                    Spacer(),
                    Text(t('Edit'), style: body(13, color: kG, weight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
            SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final m in mains)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m),
                      selected: filter == m,
                      showCheckmark: false,
                      labelStyle: body(12.5,
                          color: filter == m ? Colors.white : kInk, weight: FontWeight.w700),
                      selectedColor: kG,
                      backgroundColor: kBg,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onSelected: (_) => setState(() => filter = m),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: kLine),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (final l in shown.where((x) => s.stockOf(x) > 0)) _productRow(context, s, l),
            if (shown.any((x) => s.stockOf(x) == 0)) outOfStockHeader(shown.where((x) => s.stockOf(x) == 0).length),
            for (final l in shown.where((x) => s.stockOf(x) == 0)) _productRow(context, s, l),
          ]),
        ),
        SizedBox(height: 20),
      ]),
    );
  }

  Widget _productRow(BuildContext context, AppState s, Listing l) {
    final p = productById(l.productId);
    final out = s.stockOf(l) == 0;
    final info = Row(children: [
      out ? greyed(EmojiTile(p.emoji, size: 58)) : EmojiTile(p.emoji, size: 58),
      SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: body(14, weight: FontWeight.w600)),
          Text(p.size, style: body(12, color: kMute)),
          SizedBox(height: 2),
          Row(children: [
            Text(rupees(l.price), style: body(15, weight: FontWeight.w800)),
            if (l.price < p.mrp) ...[
              SizedBox(width: 6),
              Text(rupees(p.mrp), style: body(12, color: kMute).copyWith(decoration: TextDecoration.lineThrough)),
            ],
          ]),
          if (out) Text(t('OUT OF STOCK'), style: body(10.5, color: kRed, weight: FontWeight.w700)),
        ]),
      ),
    ]);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        Expanded(child: out ? Opacity(opacity: 0.45, child: IgnorePointer(child: info)) : info),
        out
            ? NotifyButton(
                on: s.isNotifyOn(widget.store.id, p.id),
                onTap: () {
                  final wasOn = s.isNotifyOn(widget.store.id, p.id);
                  s.toggleNotify(widget.store.id, p.id);
                  showToast(
                      context,
                      wasOn
                          ? 'Alert turned off'
                          : '🔔 We’ll notify you when ${p.name} is back at ${widget.store.name}');
                },
              )
            : QtyStepper(
                qty: s.qtyOf(widget.store.id, p.id),
                onAdd: () => tryAddToCart(context, widget.store.id, p.id),
                onRemove: () => s.remove(p.id),
              ),
      ]),
    );
  }
}
