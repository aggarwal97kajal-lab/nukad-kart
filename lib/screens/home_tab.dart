import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'search_screen.dart';
import 'store_screen.dart';
import 'thela_screen.dart';
import 'subcategory_screen.dart';
import 'account_pages.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool moving = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: kGD,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                  child: Image.asset('assets/images/logo.png'),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('DELIVER TO HOME'),
                        style: body(11.5, color: Color(0xFFBDE89A), weight: FontWeight.w700)),
                    Row(children: [
                      Flexible(
                        child: Text(s.address,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: head(16, color: Colors.white)),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ]),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen())),
                  icon: Badge(
                    isLabelVisible: s.notifications.isNotEmpty,
                    label: Text('${s.notifications.length}'),
                    child: Icon(Icons.notifications_none, color: Colors.white),
                  ),
                ),
              ]),
              SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen())),
                child: Container(
                  height: 46,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                  child: Row(children: [
                    Icon(Icons.search, color: kInk),
                    SizedBox(width: 10),
                    Expanded(child: Text(t('Search atta, doodh, tamatar…'), style: body(14.5, color: kMute))),
                    Icon(Icons.mic_none, color: kG),
                  ]),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(color: Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _seg(t('Shops'), Icons.storefront, !moving, () => setState(() => moving = false)),
                  _seg('${t('Moving sellers')} · ${kThelas.length}', Icons.shopping_cart_outlined, moving,
                      () => setState(() => moving = true)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      Expanded(child: moving ? _movingList(context) : _shopList(context)),
    ]);
  }

  Widget _seg(String text, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? kGD : Color(0xFFD7EED0)),
            SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: body(13, color: active ? kGD : Color(0xFFD7EED0), weight: active ? FontWeight.w800 : FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _shopList(BuildContext context) {
    final quick = [
      kCategories[0].subs[0],
      kCategories[0].subs[2],
      kCategories[1].subs[0],
      kCategories[3].subs[3],
    ];
    return ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final sub in quick)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryScreen(sub: sub))),
            child: SizedBox(
              width: 78,
              child: Column(children: [
                EmojiTile(sub.emoji, size: 70, bg: Color(0xFFFFF0E8)),
                SizedBox(height: 6),
                Text(sub.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: body(11.5, weight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
      SizedBox(height: 18),
      Text(t('Shops within 500 m'), style: head(17)),
      SizedBox(height: 10),
      for (final st in kStores) ...[
        _StoreCard(store: st),
        SizedBox(height: 10),
      ],
      Text(t('You pay the store at delivery, cash or UPI. Nukad Kart adds no fee to your bill.'),
          style: body(11.5, color: kMute)),
    ]);
  }

  Widget _movingList(BuildContext context) {
    return ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Text(t('Moving sellers near you'), style: head(17)),
      SizedBox(height: 4),
      Text(t('Call or WhatsApp them, then pay in person. Only sellers within 500 m are shown.'),
          style: body(12.5, color: kMute)),
      SizedBox(height: 12),
      for (final th in kThelas) ...[
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThelaScreen(thela: th))),
          child: CardBox(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              EmojiTile(th.items.first.emoji, size: 54, bg: kGBg),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(th.name, style: head(15)),
                  SizedBox(height: 2),
                  Text('${th.sells} · ${th.distanceM} m · ★ ${th.rating}', style: body(12, color: kMute)),
                  SizedBox(height: 5),
                  Wrap(spacing: 5, children: [
                    Pill('● Live', color: kGText, bg: kPillBg),
                    if (th.door) Pill(t('Comes to door')),
                    if (th.pickup) Pill(t('Pickup at thela'), color: kBlu, bg: kBluBg),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right, color: kMute),
            ]),
          ),
        ),
        SizedBox(height: 10),
      ],
    ]);
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  const _StoreCard({required this.store});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(store: store))),
      child: CardBox(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: kGBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.storefront, color: kG, size: 28),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.name, style: head(15)),
              SizedBox(height: 2),
              Text('${store.distanceM} m · Open till ${store.openTill} · ★ ${store.rating}',
                  style: body(12, color: kMute)),
              SizedBox(height: 5),
              Wrap(spacing: 5, children: [
                if (store.door) Pill(t('Door delivery')),
                if (store.pickup) Pill(t('Pickup'), color: kBlu, bg: kBluBg),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right, color: kMute),
        ]),
      ),
    );
  }
}
