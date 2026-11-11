import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import '../widgets/cart_widgets.dart';
import 'rating_sheet.dart';

/// H11 / H12: big shop photo that shrinks into the top bar as you scroll,
/// shop details, search inside the shop, category chips and a 2-column grid.
class StoreScreen extends StatefulWidget {
  final Store store;
  const StoreScreen({super.key, required this.store});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String filter = 'All';
  String query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _mainOf(Listing l) {
    final p = productById(l.productId);
    return kCategories.firstWhere((c) => c.subs.any((sb) => sb.name == p.sub)).name;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = widget.store;
    final all = listingsForStore(st.id);
    final counts = <String, int>{};
    for (final l in all) {
      counts.update(_mainOf(l), (v) => v + 1, ifAbsent: () => 1);
    }
    final chips = <MapEntry<String, int>>[MapEntry('All', all.length), ...counts.entries];
    final q = query.trim().toLowerCase();
    var shown = filter == 'All' ? all : all.where((l) => _mainOf(l) == filter).toList();
    if (q.isNotEmpty) {
      shown = shown.where((l) {
        final p = productById(l.productId);
        return p.name.toLowerCase().contains(q) || p.sub.toLowerCase().contains(q);
      }).toList();
    }
    final inStock = shown.where((x) => s.stockOf(x) > 0).toList();
    final out = shown.where((x) => s.stockOf(x) == 0).toList();
    final saved = s.bookmarks.contains(st.id);

    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: CartBar(),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: 250,
          backgroundColor: kCard,
          surfaceTintColor: kCard,
          foregroundColor: kInk,
          leading: _roundButton(Icons.arrow_back, () => Navigator.pop(context)),
          actions: [
            _roundButton(saved ? Icons.bookmark : Icons.bookmark_border, () {
              s.toggleBookmark(st.id);
              showToast(context, s.bookmarks.contains(st.id) ? 'Store bookmarked' : 'Bookmark removed');
            }, color: saved ? kLime : Colors.white),
            SizedBox(width: 8),
          ],
          flexibleSpace: LayoutBuilder(builder: (context, c) {
            final top = MediaQuery.of(context).padding.top;
            final collapsed = c.maxHeight <= kToolbarHeight + top + 8;
            return FlexibleSpaceBar(
              stretchModes: [StretchMode.zoomBackground],
              titlePadding: EdgeInsetsDirectional.only(start: 64, bottom: 14, end: 60),
              title: AnimatedOpacity(
                opacity: collapsed ? 1.0 : 0.0,
                duration: Duration(milliseconds: 180),
                child: Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: head(16)),
              ),
              background: Hero(
                tag: 'store-photo-${st.id}',
                child: Image.asset(st.photo, fit: BoxFit.cover),
              ),
            );
          }),
        ),
        SliverToBoxAdapter(child: _details(context, s, st)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => query = v),
              style: body(14.5, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search in ${st.name}…',
                hintStyle: body(14, color: kMute),
                prefixIcon: Icon(Icons.search, color: kInk),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                              query = '';
                              _search.clear();
                            }),
                        icon: Icon(Icons.close, color: kMute)),
                filled: true,
                fillColor: kCard,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: kLine)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: kG, width: 2)),
              ),
            ),
          ),
        ),
        SliverPersistentHeader(pinned: true, delegate: _ChipsHeader(chips, filter, (v) => setState(() => filter = v))),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(q.isEmpty ? 'Nothing here yet' : 'No match for “$query” in this shop',
                  textAlign: TextAlign.center, style: body(14, color: kMute)),
            ),
          ),
        _grid(context, s, inStock, false),
        if (out.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: outOfStockHeader(out.length))),
        _grid(context, s, out, true),
        SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) => Padding(
        padding: EdgeInsets.all(8),
        child: Material(
          color: Color(0x59000000),
          shape: CircleBorder(),
          child: InkWell(
            customBorder: CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 40, height: 40, child: Icon(icon, color: color, size: 21)),
          ),
        ),
      );

  Widget _details(BuildContext context, AppState s, Store st) {
    final myRating = s.ratings[st.id];
    Widget line(IconData i, String text) => Padding(
          padding: EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 17, color: kMute),
            SizedBox(width: 8),
            Expanded(child: Text(text, style: body(13.5, color: kInk))),
          ]),
        );
    return Container(
      color: kCard,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(st.name, style: head(22))),
          if (!st.isOpen) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: kRedBg, borderRadius: BorderRadius.circular(14)),
              child: Text('Closed', style: body(13, color: kRed, weight: FontWeight.w800)),
            ),
            SizedBox(width: 6),
          ],
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: kPillBg, borderRadius: BorderRadius.circular(14)),
            child: Text('★ ${st.rating} (${st.ratingCount})', style: body(13, color: kGText, weight: FontWeight.w800)),
          ),
        ]),
        line(Icons.place_outlined, '${st.distanceM} m from ${s.current.label.toLowerCase() == 'home' ? 'your home' : s.current.label}'),
        line(Icons.schedule, st.isOpen ? '${st.hours} · Open now' : '${st.hours} · Closed, opens ${st.opensAt}'),
        line(Icons.storefront_outlined, st.address),
        SizedBox(height: 10),
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
      ]),
    );
  }

  Widget _grid(BuildContext context, AppState s, List<Listing> items, bool out) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 268),
        delegate: SliverChildBuilderDelegate((context, i) => _card(context, s, items[i], out), childCount: items.length),
      ),
    );
  }

  Widget _card(BuildContext context, AppState s, Listing l, bool out) {
    final p = productById(l.productId);
    final off = p.mrp > l.price ? ((p.mrp - l.price) * 100 / p.mrp).round() : 0;
    final fav = s.wishlist.contains(p.id);
    final top = Stack(children: [
      Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: gDark ? Color(0xFF2A2420) : Color(0xFFFFF4EC), borderRadius: BorderRadius.circular(12)),
        child: Text(p.emoji, style: TextStyle(fontSize: 56)),
      ),
      if (off > 0)
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: kG, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(8))),
            child: Text('$off% OFF', style: body(10.5, color: Colors.white, weight: FontWeight.w800)),
          ),
        ),
      Positioned(
        right: 4,
        top: 4,
        child: GestureDetector(
          onTap: () => s.toggleWishlist(p.id),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: kCard, shape: BoxShape.circle),
            child: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 17, color: fav ? kRed : kMute),
          ),
        ),
      ),
    ]);
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      out ? greyed(top) : top,
      SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w600)),
      ),
      Text(p.size, style: body(11.5, color: kMute)),
      SizedBox(height: 4),
      Row(children: [
        Text(rupees(l.price), style: body(15, weight: FontWeight.w800)),
        if (off > 0) ...[
          SizedBox(width: 6),
          Text(rupees(p.mrp), style: body(11.5, color: kMute).copyWith(decoration: TextDecoration.lineThrough)),
        ],
      ]),
    ]);
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        out ? Opacity(opacity: 0.5, child: IgnorePointer(child: info)) : info,
        Spacer(),
        if (out)
          Center(
            child: NotifyButton(
              on: s.isNotifyOn(widget.store.id, p.id),
              onTap: () {
                final wasOn = s.isNotifyOn(widget.store.id, p.id);
                s.toggleNotify(widget.store.id, p.id);
                showToast(context,
                    wasOn ? 'Alert turned off' : '🔔 We’ll notify you when ${p.name} is back at ${widget.store.name}');
              },
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: QtyStepper(
              qty: s.qtyOf(widget.store.id, p.id),
              onAdd: () => tryAddToCart(context, widget.store.id, p.id),
              onRemove: () => s.remove(p.id),
            ),
          ),
      ]),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  final List<MapEntry<String, int>> chips;
  final String selected;
  final ValueChanged<String> onTap;
  _ChipsHeader(this.chips, this.selected, this.onTap);

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: kBg,
      padding: EdgeInsets.symmetric(vertical: 9),
      child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 16), children: [
        for (final c in chips)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${c.key}  ${c.value}'),
              selected: selected == c.key,
              showCheckmark: false,
              labelStyle: body(12.5, color: selected == c.key ? kGText : kInk, weight: FontWeight.w700),
              selectedColor: kPillBg,
              backgroundColor: kCard,
              side: BorderSide(color: selected == c.key ? kG : kLine, width: selected == c.key ? 1.5 : 1),
              shape: StadiumBorder(),
              onSelected: (_) => onTap(c.key),
            ),
          ),
      ]),
    );
  }

  @override
  bool shouldRebuild(covariant _ChipsHeader old) => old.selected != selected || old.chips.length != chips.length;
}
