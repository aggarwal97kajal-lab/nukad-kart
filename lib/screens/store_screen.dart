import 'package:flutter/material.dart';
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
      bottomNavigationBar: const CartBar(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: kInk,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.name, style: head(18)),
          Text('${st.distanceM} m · Open till ${st.openTill} · ★ ${st.rating} (${st.ratingCount})',
              style: body(12, color: kMute)),
        ]),
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (st.door) const Pill('Door delivery'),
              if (st.pickup) const Pill('Pickup', color: kBlu, bg: kBluBg),
              const Pill('Pay at delivery', color: kGD, bg: Color(0xFFD9F0CF)),
            ]),
            if (myRating != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => showRatingSheet(context, vendorId: st.id, vendorName: st.name, editing: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Text('Your rating', style: body(12.5, color: kMute)),
                    const SizedBox(width: 8),
                    StarRow(value: myRating, size: 16),
                    const Spacer(),
                    Text('Edit', style: body(13, color: kG, weight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final m in mains)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
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
        const Divider(height: 1, color: kLine),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (final l in shown) _productRow(context, s, l),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _productRow(BuildContext context, AppState s, Listing l) {
    final p = productById(l.productId);
    final out = l.stock == 0;
    return Opacity(
      opacity: out ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
        child: Row(children: [
          EmojiTile(p.emoji, size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: body(14, weight: FontWeight.w600)),
              Text(p.size, style: body(12, color: kMute)),
              const SizedBox(height: 2),
              Row(children: [
                Text(rupees(l.price), style: body(15, weight: FontWeight.w800)),
                if (l.price < p.mrp) ...[
                  const SizedBox(width: 6),
                  Text(rupees(p.mrp),
                      style: body(12, color: kMute).copyWith(decoration: TextDecoration.lineThrough)),
                ],
              ]),
            ]),
          ),
          out
              ? const Pill('Out of stock', color: kRed, bg: kRedBg)
              : QtyStepper(
                  qty: s.qtyOf(widget.store.id, p.id),
                  onAdd: () => tryAddToCart(context, widget.store.id, p.id),
                  onRemove: () => s.remove(p.id),
                ),
        ]),
      ),
    );
  }
}
